package main

import (
	"sort"
	"strings"
)

type ReleaseEntry struct {
	Path string
	Size string
	Sha  string
	Md5  string
}

type ReleaseInfo struct {
	Fields       map[string]string
	HasChecksums bool
	Entries      map[string]ReleaseEntry
}

func (r *ReleaseInfo) Get(k string) string {
	return strings.TrimSpace(r.Fields[strings.ToLower(k)])
}

var shaSections = []string{"checksums-sha512:", "sha512:", "checksums-sha256:", "sha256sum:", "sha256:"}
var md5Sections = []string{"checksums-md5:", "md5sum:", "md5:"}

func parseRelease(data []byte) *ReleaseInfo {
	ri := &ReleaseInfo{Fields: map[string]string{}, Entries: map[string]ReleaseEntry{}}
	lines := strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n")
	var secKind string // "", "sha", "md5"
	for _, line := range lines {
		switch {
		case strings.TrimSpace(line) == "":
			secKind = ""
			continue
		case line[0] == ' ' || line[0] == '\t':
			if secKind == "" {
				continue
			}
			parts := strings.Fields(line)
			if len(parts) < 3 {
				continue
			}
			path := parts[2]
			e := ri.Entries[path]
			e.Path = path
			e.Size = parts[1]
			if secKind == "sha" {
				e.Sha = parts[0]
			} else if secKind == "md5" {
				e.Md5 = parts[0]
			}
			ri.Entries[path] = e
			continue
		}
		colon := strings.Index(line, ":")
		if colon < 0 {
			continue
		}
		key := strings.ToLower(line[:colon+1])
		ri.Fields[strings.TrimSuffix(key, ":")] = strings.TrimSpace(line[colon+1:])
		secKind = ""
		for _, s := range shaSections {
			if key == s {
				secKind = "sha"
				ri.HasChecksums = true
				break
			}
		}
		if secKind == "" {
			for _, s := range md5Sections {
				if key == s {
					secKind = "md5"
					ri.HasChecksums = true
					break
				}
			}
		}
	}
	return ri
}

func (ri *ReleaseInfo) Suites() []string {
	var out []string
	seen := map[string]bool{}
	for _, v := range []string{ri.Get("suite"), ri.Get("codename")} {
		if v != "" && !seen[v] {
			seen[v] = true
			out = append(out, v)
		}
	}
	if ri.Get("variants") != "" {
		for _, v := range strings.Fields(ri.Get("variants")) {
			if !seen[v] {
				seen[v] = true
				out = append(out, v)
			}
		}
	}
	if len(out) == 0 {
		out = append(out, "stable")
	}
	return out
}

func (ri *ReleaseInfo) Components() []string {
	if comps := strings.Fields(ri.Get("components")); len(comps) > 0 {
		return comps
	}
	return []string{"main"}
}

func (ri *ReleaseInfo) Architectures() []string {
	if archs := strings.Fields(ri.Get("architectures")); len(archs) > 0 {
		return archs
	}
	return []string{"iphoneos-arm"}
}

var indexExts = []string{"", ".gz", ".bz2", ".xz", ".lzma"}

// discovery returns the paths worth fetching: every explicitly listed index
// path plus standard probes for root-level and dists-based layouts
func discovery(ri *ReleaseInfo) (listed, probes []string) {
	seen := map[string]bool{}
	add := func(p string) {
		p = strings.TrimPrefix(p, "./")
		if p == "" || seen[p] || !isIndexPath(p) {
			return
		}
		seen[p] = true
		listed = append(listed, p)
	}
	if ri != nil && ri.HasChecksums {
		paths := make([]string, 0, len(ri.Entries))
		for p := range ri.Entries {
			paths = append(paths, p)
		}
		sort.Strings(paths)
		for _, p := range paths {
			if p == "Release" || strings.HasSuffix(p, "/Release") {
				continue
			}
			add(p)
		}
	}
	for _, e := range indexExts {
		name := "Packages" + e
		if !seen[name] {
			seen[name] = true
			probes = append(probes, name)
		}
	}
	if ri != nil {
		for _, suite := range ri.Suites() {
			for _, comp := range ri.Components() {
				for _, arch := range ri.Architectures() {
					for _, e := range indexExts {
						p := "dists/" + suite + "/" + comp + "/binary-" + arch + "/Packages" + e
						if !seen[p] {
							seen[p] = true
							probes = append(probes, p)
						}
					}
				}
			}
		}
	}
	sort.Strings(listed)
	sort.Strings(probes)
	return listed, probes
}

func isIndexPath(p string) bool {
	if p == "Packages" {
		return true
	}
	if strings.HasSuffix(p, ".diff") {
		return false
	}
	return strings.HasPrefix(p, "Packages.")
}
