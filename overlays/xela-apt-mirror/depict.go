package main

import (
	"bytes"
	"errors"
	"log"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
)

var (
	attrDQRe = regexp.MustCompile(`(?i)\b(src|href|poster|data-src)\s*=\s*"([^"]*)"`)
	attrSQRe = regexp.MustCompile(`(?i)\b(src|href|poster|data-src)\s*=\s*'([^']*)'`)
	srcsetRe = regexp.MustCompile(`(?i)\bsrcset\s*=\s*"([^"]*)"`)
	cssURLRe = regexp.MustCompile(`(?i)url\(\s*((?:'[^']*')|(?:"[^"]*")|(?:[^'")][^)]*))\s*\)`)
)

var (
	errShortBody = errors.New("empty body")
	resMu        sync.Mutex
	depMu        sync.Mutex
	iconMu       sync.Mutex
)

func sameHost(u1, u2 string) bool {
	h1, h2 := hostOf(u1), hostOf(u2)
	return h1 != "" && h1 == h2
}

func sortedSet(vals []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, v := range vals {
		if !seen[v] {
			seen[v] = true
			out = append(out, v)
		}
	}
	sort.Strings(out)
	return out
}

func assetBaseName(urlStr string) string {
	uu, err := url.Parse(urlStr)
	if err != nil {
		return "asset"
	}
	return sanitizeName(path.Base(uu.Path))
}

func safeAssetName(urlStr string) string {
	return sha256Hex([]byte(urlStr))[:16] + "-" + assetBaseName(urlStr)
}

func looksLikeCSS(uurl, contentType string, body []byte) bool {
	if strings.Contains(contentType, "text/css") {
		return true
	}
	uu, err := url.Parse(uurl)
	if err == nil && strings.HasSuffix(strings.ToLower(uu.Path), ".css") {
		return true
	}
	head := bytes.ToUpper(body[:min(len(body), 512)])
	return bytes.Contains(head, []byte("{")) && !bytes.Contains(head, []byte("<"))
}

// extractAssetCands collects every same-origin absolute URL referenced from
// the depiction HTML (img/script/link/style sources and CSS url()s)
func extractAssetCands(html []byte, baseURL string) []string {
	var vals []string
	add := func(raw string, isSrcset bool) {
		handle := func(ref string) {
			if strings.ContainsAny(ref, "'\" ") || strings.Contains(ref, "${") {
				return
			}
			if resolved, ok := resolveRef(baseURL, ref); ok {
				vals = append(vals, resolved)
			}
		}
		if isSrcset {
			for _, part := range strings.Split(raw, ",") {
				handle(strings.TrimSpace(strings.SplitN(strings.TrimSpace(part), " ", 2)[0]))
			}
			return
		}
		handle(raw)
	}
	for _, m := range attrDQRe.FindAllStringSubmatch(string(html), -1) {
		add(m[2], false)
	}
	for _, m := range attrSQRe.FindAllStringSubmatch(string(html), -1) {
		add(m[2], false)
	}
	for _, m := range srcsetRe.FindAllStringSubmatch(string(html), -1) {
		add(m[1], true)
	}
	for _, m := range cssURLRe.FindAllStringSubmatch(string(html), -1) {
		add(cssURLValue(m[1]), false)
	}
	cands := sortedSet(vals)
	out := cands[:0]
	for _, c := range cands {
		if sameHost(c, baseURL) {
			out = append(out, c)
		}
	}
	return out
}

// swapRef replaces the value slot inside a matched attribute/url() snippet
func swapRef(match, oldVal, newVal string) string {
	return strings.Replace(match, oldVal, newVal, 1)
}

// cssURLValue strips optional quotes from a url(...) capture group
func cssURLValue(raw string) string {
	if len(raw) >= 2 && (raw[:1] == "'" || raw[:1] == `"`) && raw[len(raw)-1:] == raw[:1] {
		return raw[1 : len(raw)-1]
	}
	return strings.TrimSpace(raw)
}

// rewriteRefs rewrites attribute and CSS url() references using url->value pairs
func rewriteRefs(body []byte, baseURL string, refMap map[string]string, prefix string) []byte {
	mapOnly := func(raw string) (string, bool) {
		if len(refMap) == 0 {
			return "", false
		}
		if v, ok := resolveRef(baseURL, raw); ok && refMap[v] != "" {
			return prefix + refMap[v], true
		}
		return "", false
	}
	out := attrDQRe.ReplaceAllStringFunc(string(body), func(m string) string {
		g := attrDQRe.FindStringSubmatch(m)
		if v, ok := mapOnly(g[2]); ok {
			return swapRef(m, g[2], v)
		}
		return m
	})
	out = attrSQRe.ReplaceAllStringFunc(out, func(m string) string {
		g := attrSQRe.FindStringSubmatch(m)
		if v, ok := mapOnly(g[2]); ok {
			return swapRef(m, g[2], v)
		}
		return m
	})
	out = srcsetRe.ReplaceAllStringFunc(out, func(m string) string {
		g := srcsetRe.FindStringSubmatch(m)
		var rebuilt []string
		changed := false
		for _, part := range strings.Split(g[1], ",") {
			part = strings.TrimSpace(part)
			urlPart := strings.TrimSpace(strings.SplitN(part, " ", 2)[0])
			if v, ok := mapOnly(urlPart); ok {
				rebuilt = append(rebuilt, swapRef(part, urlPart, v))
				changed = true
			} else {
				rebuilt = append(rebuilt, part)
			}
		}
		if changed {
			return swapRef(m, g[1], strings.Join(rebuilt, ", "))
		}
		return m
	})
	out = cssURLRe.ReplaceAllStringFunc(out, func(m string) string {
		g := cssURLRe.FindStringSubmatch(m)
		val := cssURLValue(g[1])
		if v, ok := mapOnly(val); ok {
			return swapRef(m, val, v)
		}
		return m
	})
	return []byte(out)
}

func resolveRefOK(raw string, baseURL string, refMap map[string]string) (string, bool) {
	v, ok := resolveRef(baseURL, raw)
	if ok && refMap[v] != "" {
		return v, true
	}
	return "", false
}

// fetchAssets...
func fetchAssets(f *Fetcher, assetsDir string, cands []string, depth int) map[string]string {
	res := map[string]string{}
	if len(cands) == 0 || depth > 3 {
		return res
	}
	errs := runPool(3, len(cands), func(i int) error {
		raw := cands[i]
		body, ct, err := f.Fetch(raw)
		if err != nil || len(body) == 0 {
			if err == nil {
				return errShortBody
			}
			return err
		}
		content := body
		if looksLikeCSS(raw, ct, body) {
			inner := fetchAssets(f, assetsDir, extractAssetCands(content, raw), depth+1)
			content = rewriteRefs(content, raw, inner, "")
		}
		name := safeAssetName(raw)
		if err := writeAtomic(filepath.Join(assetsDir, name), content); err != nil {
			return err
		}
		resMu.Lock()
		res[raw] = name
		resMu.Unlock()
		return nil
	})
	for i, err := range errs {
		if err != nil {
			log.Printf("asset %s: %v", cands[i], err)
		}
	}
	return res
}

// collectIcons archives package icons, returning pkg-id -> local rel path
func collectIcons(f *Fetcher, baseURL, repoDir string, entries []PkgEntry) (map[string]string, int) {
	urlKit := map[string]string{}
	type iconJob struct{ raw, url string }
	var jobs []iconJob
	seen := map[string]bool{}
	for _, e := range entries {
		id := e.ID()
		req := strings.TrimSpace(e.Get("icon"))
		if id == "" || req == "" {
			continue
		}
		resolved, ok := resolveRef(baseURL, req)
		if !ok || seen[resolved] {
			continue
		}
		seen[resolved] = true
		jobs = append(jobs, iconJob{raw: req, url: resolved})
	}
	errs := runPool(3, len(jobs), func(i int) error {
		j := jobs[i]
		name := sanitizeName(assetBaseName(j.url)) + "_" + guessImageExt(j.url)
		body, _, err := f.Fetch(j.url)
		if err != nil {
			return err
		}
		if len(body) == 0 {
			return errShortBody
		}
		name = sanitizeName(assetBaseName(j.url)) + "_" + sha256Hex(body)[:8] + guessImageExt(j.url)
		dest := filepath.Join(repoDir, "_archive", "icons", name)
		if err := writeAtomic(dest, body); err != nil {
			return err
		}
		iconMu.Lock()
		urlKit[j.url] = name
		iconMu.Unlock()
		return nil
	})
	for i, err := range errs {
		if err != nil {
			log.Printf("icon %s: %v", jobs[i].url, err)
		}
	}
	iconByPkg := map[string]string{}
	for _, e := range entries {
		id := e.ID()
		if id == "" || iconByPkg[id] != "" {
			continue
		}
		resolved, ok := resolveRef(baseURL, strings.TrimSpace(e.Get("icon")))
		if !ok {
			continue
		}
		if name := urlKit[resolved]; name != "" {
			iconByPkg[id] = "_archive/icons/" + name
		}
	}
	return iconByPkg, len(urlKit)
}

func guessImageExt(raw string) string {
	uu, err := url.Parse(raw)
	if err == nil {
		switch strings.ToLower(path.Ext(uu.Path)) {
		case ".png":
			return ".png"
		case ".gif":
			return ".gif"
		case ".jpg", ".jpeg":
			return ".jpg"
		case ".svg":
			return ".svg"
		case ".webp":
			return ".webp"
		}
	}
	return ".png"
}

// collectDepictions archives every unique Depiction/SileoDepiction page as
// rendered HTML; returns url -> archived rel path for successfully archived URLs
func collectDepictions(f *Fetcher, baseURL, repoDir string, entries []PkgEntry) (map[string]string, int) {
	type depJob struct {
		id, raw, url string
	}
	var jobs []depJob
	seen := map[string]bool{}
	for _, e := range entries {
		for _, key := range []string{"depiction", "sileodepiction"} {
			raw := strings.TrimSpace(e.Get(key))
			if raw == "" || e.ID() == "" {
				continue
			}
			resolved, ok := resolveRef(baseURL, raw)
			if !ok || seen[resolved] {
				continue
			}
			seen[resolved] = true
			jobs = append(jobs, depJob{id: e.ID(), raw: raw, url: resolved})
		}
	}
	archived := map[string]string{}
	errs := runPool(3, len(jobs), func(i int) error {
		j := jobs[i]
		rel := "_archive/depictions/" + sanitizeName(j.id) + "-" + sha256Hex([]byte(j.url))[:8] + ".html"
		dest := filepath.Join(repoDir, "_archive", "depictions", sanitizeName(j.id)+"-"+sha256Hex([]byte(j.url))[:8]+".html")
		body, _, err := f.Fetch(j.url)
		if err != nil {
			return err
		}
		if len(body) == 0 {
			return errShortBody
		}
		assetsDir := filepath.Join(repoDir, "_archive", "assets")
		assets := fetchAssets(f, assetsDir, extractAssetCands(body, j.url), 0)
		rewritten := rewriteRefs(body, j.url, assets, "../assets/")
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(dest, rewritten, 0o644); err != nil {
			return err
		}
		depMu.Lock()
		archived[j.url] = rel
		depMu.Unlock()
		return nil
	})
	for i, err := range errs {
		if err != nil {
			log.Printf("depiction %s: %v", jobs[i].url, err)
		}
	}
	return archived, len(jobs)
}
