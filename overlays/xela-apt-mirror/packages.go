package main

import (
	"bytes"
	"compress/bzip2"
	"compress/gzip"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"fmt"
	"hash"
	"io"
	"path"
	"strconv"
	"strings"
)

type PkgEntry struct {
	Fields map[string]string
}

func (p *PkgEntry) Get(key string) string {
	if p == nil || p.Fields == nil {
		return ""
	}
	return p.Fields[strings.ToLower(key)]
}

func (p *PkgEntry) ID() string      { return p.Get("package") }
func (p *PkgEntry) Version() string { return p.Get("version") }
func (p *PkgEntry) Filename() string {
	return strings.TrimPrefix(p.Get("filename"), "./")
}

func parsePackages(data []byte) []PkgEntry {
	var entries []PkgEntry
	lines := strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n")
	var cur *PkgEntry
	var curKey string
	var val []string
	flush := func() {
		if cur != nil && curKey != "" {
			cur.Fields[curKey] = strings.Join(val, "\n")
		}
		curKey = ""
		val = nil
	}
	endBlock := func() {
		flush()
		if cur != nil && cur.ID() != "" {
			entries = append(entries, *cur)
		}
		cur = nil
	}
	for _, line := range lines {
		if line == "" {
			endBlock()
			continue
		}
		if line[0] == ' ' || line[0] == '\t' {
			if curKey != "" {
				val = append(val, strings.TrimSpace(line))
			}
			continue
		}
		colon := strings.Index(line, ":")
		if colon < 0 {
			continue
		}
		flush()
		if cur == nil {
			cur = &PkgEntry{Fields: map[string]string{}}
		}
		curKey = strings.ToLower(string(line[:colon]))
		val = []string{strings.TrimSpace(line[colon+1:])}
	}
	endBlock()
	return entries
}

// gzipIndex encodes a plain index body as gzip
func gzipIndex(body []byte) []byte {
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	if _, err := zw.Write(body); err != nil {
		zw.Close()
		return nil
	}
	if err := zw.Close(); err != nil {
		return nil
	}
	return buf.Bytes()
}

// indexReencode re-encodes a (rewritten) decompressed index body back to
// the on-disk format its path implies. editable=false marks formats the
// stdlib cannot regenerate (bz2/xz/lzma/zst) — with the external-URL
// Filename rewrite active those variants are not mirrored at all
func indexReencode(indexPath string, decoded []byte) ([]byte, bool) {
	switch strings.TrimPrefix(path.Base(indexPath), "Packages") {
	case "":
		return decoded, true
	case ".gz":
		return gzipIndex(decoded), true
	default:
		return nil, false
	}
}

// checksumHex is an apt grouping of hashlib writers for Release checksum
// sections
func checksumHex(name string, b []byte) string {
	var h hash.Hash
	switch name {
	case "md5sum":
		h = md5.New()
	case "sha1":
		h = sha1.New()
	case "sha256":
		h = sha256.New()
	case "sha512":
		h = sha512.New()
	default:
		return ""
	}
	h.Write(b)
	return hex.EncodeToString(h.Sum(nil))
}

// rewriteReleaseChecksums recomputes a mirrored Release body's checksum
// lists to match what the mirror actually stores: updated maps an index's
// path as the Release body lists it (branch-relative) to its final stored
// bytes; dropped lists files intentionally not mirrored (compressed
// variants the rewrite pass cannot regenerate), which are removed from
// the lists. Unrelated lines pass through untouched
func rewriteReleaseChecksums(relBody []byte, updated map[string][]byte, dropped map[string]bool) []byte {
	if len(updated) == 0 && len(dropped) == 0 {
		return relBody
	}
	lines := strings.Split(strings.ReplaceAll(string(relBody), "\r\n", "\n"), "\n")
	algo := "" // current checksum section name, "" outside one
	out := make([]string, 0, len(lines))
	for _, line := range lines {
		var curAlgo string
		// header detection tolerates whitespace after the colon ("SHA256: "),
		// which parseRelease already does (it keys on line[:colon+1])
		switch strings.TrimSuffix(strings.ToLower(strings.TrimSpace(line)), ":") {
		case "md5sum", "md5", "checksums-md5":
			curAlgo = "md5sum"
		case "sha1", "checksums-sha1":
			curAlgo = "sha1"
		case "sha256", "sha256sum", "checksums-sha256":
			curAlgo = "sha256"
		case "sha512", "checksums-sha512":
			curAlgo = "sha512"
		}
		if curAlgo != "" {
			// a checksum section header never begins with whitespace
			algo = curAlgo
			out = append(out, line)
			continue
		}
		if line == "" || (line[0] != ' ' && line[0] != '\t') {
			// unrelated top-level field (or blank line): reset so entries
			// of a later unrecognized section can never inherit a stale
			// algorithm (mirrors parseRelease's section tracking, which
			// accepts both space- and tab-indented entries)
			algo = ""
			out = append(out, line)
			continue
		}
		if algo == "" {
			out = append(out, line)
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 3 {
			out = append(out, line)
			continue
		}
		pth := strings.TrimPrefix(fields[2], "./")
		if dropped[pth] {
			continue // removed from the listing: not mirrored
		}
		if body, ok := updated[pth]; ok {
			lead := line[:len(line)-len(strings.TrimLeft(line, " \t"))]
			out = append(out, lead+checksumHex(algo, body)+" "+
				strconv.FormatInt(int64(len(body)), 10)+" "+fields[2])
			continue
		}
		out = append(out, line)
	}
	return []byte(strings.Join(out, "\n"))
}

// byMagic handles upstreams serving gzip/bzip2/xz content without a
// well-matched file extension
func decodeIndex(content []byte) ([]byte, error) {
	if len(content) < 4 {
		return content, nil
	}
	magic := content[:4]
	switch {
	case magic[0] == 0x1f && magic[1] == 0x8b:
		zr, err := gzip.NewReader(bytes.NewReader(content))
		if err != nil {
			return nil, fmt.Errorf("gzip: %w", err)
		}
		defer zr.Close()
		return io.ReadAll(io.LimitReader(zr, maxFetchBytes))
	case magic[0] == 'B' && magic[1] == 'Z' && magic[2] == 'h':
		return io.ReadAll(io.LimitReader(bzip2.NewReader(bytes.NewReader(content)), maxFetchBytes))
	case magic[0] == 0xfd && magic[1] == '3' && magic[2] == '7' && magic[3] == 'z':
		return nil, fmt.Errorf("xz-compressed indexes not supported: % x", magic)
	case magic[0] == 0x28 && magic[1] == 0xb5 && magic[2] == 0x2f && magic[3] == 0xfd:
		return nil, fmt.Errorf("zstd-compressed indexes not supported: % x", magic)
	default:
		return content, nil
	}
}
