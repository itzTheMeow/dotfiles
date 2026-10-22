package main

import (
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"hash"
	"io"
	"net/url"
	"os"
	"strings"
	"time"
)

const maxFetchBytes = 512 << 20

func sha256Hex(b []byte) string {
	s := sha256.Sum256(b)
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
