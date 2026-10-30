package main

import (
	"crypto/md5"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"fmt"
	"hash"
	"io"
	"net"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	maxFetchBytes = 512 << 20
	maxDebBytes   = 2 << 30
)

func sha256Hex(b []byte) string {
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}

func md5Hex(b []byte) string {
	s := md5.Sum(b)
	return hex.EncodeToString(s[:])
}

func sha512Hex(b []byte) string {
	s := sha512.Sum512(b)
	return hex.EncodeToString(s[:])
}

// returns nil when hashes are absent or match; error otherwise
func verifyFileHash(path, sha256Str, md5Str string) error {
	if sha256Str == "" && md5Str == "" {
		return nil
	}
	shaWant, md5Want := normalizeHex(sha256Str), normalizeHex(md5Str)
	if shaWant == "" && md5Want == "" {
		return nil
	}
	fh, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("hash open: %w", err)
	}
	defer fh.Close()
	var shaH, md5H hash.Hash
	if shaWant != "" {
		shaH = sha256.New()
	}
	if md5Want != "" {
		md5H = md5.New()
	}
	writers := []io.Writer{}
	if shaH != nil {
		writers = append(writers, shaH)
	}
	if md5H != nil {
		writers = append(writers, md5H)
	}
	mw := io.MultiWriter(writers...)
	if _, err := io.Copy(mw, fh); err != nil {
		return fmt.Errorf("hash read: %w", err)
	}
	if shaH != nil {
		if got := hex.EncodeToString(shaH.Sum(nil)); got != shaWant {
			return fmt.Errorf("sha256 mismatch: got %s want %s", got, shaWant)
		}
	}
	if md5H != nil {
		if got := hex.EncodeToString(md5H.Sum(nil)); got != md5Want {
			return fmt.Errorf("md5 mismatch: got %s want %s", got, md5Want)
		}
	}
	return nil
}

func normalizeHex(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	for _, c := range s {
		if c < '0' || c > 'f' || (c > '9' && c < 'a') {
			return ""
		}
	}
	return s
}

func hostOf(rawurl string) string {
	u, err := url.Parse(rawurl)
	if err != nil {
		return rawurl
	}
	return u.Host
}

// resolveRef turns a page/attribute reference into an absolute fetchable URL;
// false means the reference is unsupported (other schemes, parse failure)
func resolveRef(baseURL, ref string) (string, bool) {
	if ref == "" {
		return "", false
	}
	if strings.HasPrefix(ref, "http://") || strings.HasPrefix(ref, "https://") {
		return ref, true
	}
	for _, bad := range []string{"data:", "file:", "cydia://", "javascript:", "mailto:", "tel:"} {
		if strings.HasPrefix(ref, bad) {
			return "", false
		}
	}
	base, err := url.Parse(baseURL)
	if err != nil {
		return "", false
	}
	ru, err := base.Parse(ref)
	if err != nil || (ru.Scheme != "http" && ru.Scheme != "https") {
		return "", false
	}
	return ru.String(), true
}

func sanitizeName(s string) string {
	var b strings.Builder
	for _, c := range strings.ToLower(s) {
		switch {
		case c >= 'a' && c <= 'z', c >= '0' && c <= '9', c == '-', c == '_', c == '.', c == '+':
			b.WriteRune(c)
		default:
			b.WriteByte('-')
		}
	}
	return strings.Trim(b.String(), "-.")
}

func humanSize(n int64) string {
	switch {
	case n >= 1<<40:
		return fmt.Sprintf("%.2f TB", float64(n)/(1<<40))
	case n >= 1<<30:
		return fmt.Sprintf("%.2f GB", float64(n)/(1<<30))
	case n >= 1<<20:
		return fmt.Sprintf("%.1f MB", float64(n)/(1<<20))
	case n >= 1<<10:
		return fmt.Sprintf("%.1f KB", float64(n)/(1<<10))
	default:
		return fmt.Sprintf("%d B", n)
	}
}

func formatTime(t time.Time) string {
	if t.IsZero() {
		return "never"
	}
	return t.UTC().Format("2006-01-02 15:04 UTC")
}

func internalIP(ip net.IP) bool {
	// IsUnspecified: "0.0.0.0"/"::" dial back to the local host itself
	return ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsUnspecified()
}

// screenHost extracts the host portion of "host[:port]" in dialable form:
// HTTP URL hosts keep IPv6 brackets ("[::1]"), which net.SplitHostPort
// rejects when no port is present — without stripping them, bracketed IPv6
// internal literals (and trailing-dot spellings like "10.0.0.5.") dodge
// both the literal-IP check and the DNS lookup. Also drops the DNS root
// dot so ParseIP/lookups see the canonical spelling.
func screenHost(host string) string {
	h, _, err := net.SplitHostPort(host)
	if err != nil {
		h = host
	}
	if len(h) > 1 && h[0] == '[' && h[len(h)-1] == ']' {
		h = h[1 : len(h)-1]
	}
	return strings.TrimSuffix(h, ".")
}

func isInternalHost(host string) bool {
	h := screenHost(host)
	if h == "localhost" || strings.HasSuffix(h, ".localhost") {
		return true
	}
	ip := net.ParseIP(h)
	if ip == nil {
		return false
	}
	return internalIP(ip)
}

// The hostname-side of internal screening (name resolving into a private
// range). isInternalHost alone only sees literal IPs and localhost names,
// leaving names with internal A/AAAA records as an SSRF hole. Best-effort:
// a TOCTOU window always remains between this check and the transport's
// own connect (classic DNS rebinding). lookupHost is a var so tests can
// stub resolution.
var lookupHost = net.LookupHost

// Public hostnames would otherwise pay a DNS lookup on every guarded
// request; the verdict is cached briefly. Rebinding within the window is
// not caught — the cache trades completeness for not doubling resolution
// work per request.
const internalHostTTL = 30 * time.Second

type internalVerdict struct {
	internal bool
	when     time.Time
}

var (
	internalVerdictMu sync.Mutex
	internalVerdicts  = map[string]internalVerdict{}
)

// resolveInternal screens a bare (lowercased) hostname by DNS. Unresolvable
// names count as not internal — the request itself fails on connect.
func resolveInternal(name string) bool {
	internalVerdictMu.Lock()
	v, ok := internalVerdicts[name]
	internalVerdictMu.Unlock()
	if ok && time.Since(v.when) < internalHostTTL {
		return v.internal
	}
	ips, err := lookupHost(name)
	internal := false
	if err == nil {
		for _, s := range ips {
			if ip := net.ParseIP(s); ip != nil && internalIP(ip) {
				internal = true
				break
			}
		}
	}
	internalVerdictMu.Lock()
	// prune stale entries on insert: content-derived hostnames would
	// otherwise make the cache grow without bound over the process
	// lifetime
	now := time.Now()
	for k, v := range internalVerdicts {
		if now.Sub(v.when) >= internalHostTTL {
			delete(internalVerdicts, k)
		}
	}
	internalVerdicts[name] = internalVerdict{internal: internal, when: now}
	internalVerdictMu.Unlock()
	return internal
}

// screenInternal extends isInternalHost with hostname resolution: literal
// IPs never resolve here, public literal IPs return false without a lookup,
// names resolve (with the TTL cache).
func screenInternal(host string) bool {
	if isInternalHost(host) {
		return true
	}
	h := screenHost(host)
	if net.ParseIP(h) != nil {
		return false // public literal IP, nothing to resolve
	}
	return resolveInternal(strings.ToLower(h))
}
