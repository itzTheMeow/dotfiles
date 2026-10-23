package main

import (
	"bytes"
	"compress/bzip2"
	"compress/gzip"
	"fmt"
	"io"
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
