package main

import (
	"bytes"
	"errors"
	"log"
	"net/url"
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

// assetCache dedupes asset fetches across every depiction of one repo run:
// ok remembers archived urls for name reuse (no refetch), bad skips
// re-requesting urls that already failed during this run
type assetCache struct {
	mu  sync.Mutex
	ok  map[string]string
	bad map[string]string
}

func newAssetCache() *assetCache {
	return &assetCache{ok: map[string]string{}, bad: map[string]string{}}
}

func (c *assetCache) lookup(rawurl string) (name, failed string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.ok[rawurl], c.bad[rawurl]
}

func (c *assetCache) remember(rawurl, name string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.ok[rawurl] = name
}

func (c *assetCache) fail(rawurl, msg string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.bad[rawurl] = msg
}

// archived returns the number of unique assets archived so far this run
func (c *assetCache) archived() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.ok)
}

// errGroup dedupes fetch errors for one repo sync run; identical
// kind+url+error messages are flushed once with a repeat count
type errGroup struct {
	mu   sync.Mutex
	seen map[string]int
}

func (eg *errGroup) add(kind, rawurl string, err error) {
	eg.mu.Lock()
	eg.seen[kind+" "+rawurl+": "+err.Error()]++
	eg.mu.Unlock()
}

func (eg *errGroup) count() int {
	eg.mu.Lock()
	defer eg.mu.Unlock()
	n := 0
	for _, c := range eg.seen {
		n += c
	}
	return n
}

func (eg *errGroup) flush(lg *log.Logger) {
	eg.mu.Lock()
	defer eg.mu.Unlock()
	keys := make([]string, 0, len(eg.seen))
	for k := range eg.seen {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		if n := eg.seen[k]; n > 1 {
			lg.Printf("%s (repeated %dx)", k, n)
		} else {
			lg.Printf("%s", k)
		}
	}
	eg.seen = map[string]int{}
}

// archiver bundles the per-run context for the icon/depiction/asset
// collection phases; every render/provider line carries the repo prefix
type archiver struct {
	f         *Fetcher
	lg        *log.Logger
	cache     *assetCache
	eg        *errGroup
	baseURL   string
	repoDir   string
	assetsDir string
}

// fetchAssets archives a batch of same-host assets (recursing into CSS),
// deduped via the run-wide asset cache
func (a *archiver) fetchAssets(cands []string, depth int) map[string]string {
	res := map[string]string{}
	if len(cands) == 0 || depth > 3 {
		return res
	}
	var resMu sync.Mutex
	runPool(3, len(cands), func(i int) error {
		raw := cands[i]
		if name, failed := a.cache.lookup(raw); name != "" || failed != "" {
			if name == "" {
				// already failed earlier this run; keep its error counted
				a.eg.add("asset", raw, errors.New(failed))
				return nil
			}
			resMu.Lock()
			res[raw] = name
			resMu.Unlock()
			return nil
		}
		body, ct, err := a.f.Fetch(raw)
		if err != nil || len(body) == 0 {
			if err == nil {
				err = errShortBody
			}
			a.cache.fail(raw, err.Error())
			a.eg.add("asset", raw, err)
			return nil
		}
		content := body
		if looksLikeCSS(raw, ct, body) {
			inner := a.fetchAssets(extractAssetCands(content, raw), depth+1)
			content = rewriteRefs(content, raw, inner, "")
		}
		name := safeAssetName(raw)
		if err := writeAtomic(filepath.Join(a.assetsDir, name), content); err != nil {
			a.eg.add("asset", raw, err)
			return nil
		}
		a.cache.remember(raw, name)
		resMu.Lock()
		res[raw] = name
		resMu.Unlock()
		return nil
	})
	return res
}

// icons archives package icons, returning pkg-id -> local rel path
func (a *archiver) icons(entries []PkgEntry) (map[string]string, int) {
	urlKit := map[string]string{}
	var jobs []string
	seen := map[string]bool{}
	for _, e := range entries {
		id := e.ID()
		req := strings.TrimSpace(e.Get("icon"))
		if id == "" || req == "" {
			continue
		}
		resolved, ok := resolveRef(a.baseURL, req)
		if !ok || seen[resolved] {
			continue
		}
		seen[resolved] = true
		jobs = append(jobs, resolved)
	}
	if len(jobs) != 0 {
		a.lg.Printf("archiving %d icons", len(jobs))
	}
	var mu sync.Mutex
	runPool(3, len(jobs), func(i int) error {
		url := jobs[i]
		body, _, err := a.f.Fetch(url)
		if err != nil || len(body) == 0 {
			if err == nil {
				err = errShortBody
			}
			a.eg.add("icon", url, err)
			return nil
		}
		name := sanitizeName(assetBaseName(url)) + "_" + sha256Hex(body)[:8] + guessImageExt(url)
		dest := filepath.Join(a.repoDir, "_archive", "icons", name)
		if err := writeAtomic(dest, body); err != nil {
			a.eg.add("icon", url, err)
			return nil
		}
		mu.Lock()
		urlKit[url] = name
		mu.Unlock()
		return nil
	})
	iconByPkg := map[string]string{}
	for _, e := range entries {
		id := e.ID()
		if id == "" || iconByPkg[id] != "" {
			continue
		}
		resolved, ok := resolveRef(a.baseURL, strings.TrimSpace(e.Get("icon")))
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

// depictions archives every unique Depiction/SileoDepiction page as rendered
// HTML; returns url -> archived rel path for successfully archived URLs
func (a *archiver) depictions(entries []PkgEntry) (map[string]string, int) {
	var jobs []struct {
		id, url string
	}
	seen := map[string]bool{}
	for _, e := range entries {
		for _, key := range []string{"depiction", "sileodepiction"} {
			raw := strings.TrimSpace(e.Get(key))
			if raw == "" || e.ID() == "" {
				continue
			}
			resolved, ok := resolveRef(a.baseURL, raw)
			if !ok || seen[resolved] {
				continue
			}
			seen[resolved] = true
			jobs = append(jobs, struct{ id, url string }{id: e.ID(), url: resolved})
		}
	}
	if len(jobs) != 0 {
		a.lg.Printf("archiving %d depictions", len(jobs))
	}
	archived := map[string]string{}
	var mu sync.Mutex
	runPool(3, len(jobs), func(i int) error {
		j := jobs[i]
		rel := "_archive/depictions/" + sanitizeName(j.id) + "-" + sha256Hex([]byte(j.url))[:8] + ".html"
		dest := filepath.Join(a.repoDir, "_archive", "depictions", sanitizeName(j.id)+"-"+sha256Hex([]byte(j.url))[:8]+".html")
		body, _, err := a.f.Fetch(j.url)
		if err != nil || len(body) == 0 {
			if err == nil {
				err = errShortBody
			}
			a.eg.add("depiction", j.url, err)
			return nil
		}
		assets := a.fetchAssets(extractAssetCands(body, j.url), 0)
		rewritten := rewriteRefs(body, j.url, assets, "../assets/")
		if err := writeAtomic(dest, rewritten); err != nil {
			a.eg.add("depiction", j.url, err)
			return nil
		}
		mu.Lock()
		archived[j.url] = rel
		mu.Unlock()
		return nil
	})
	return archived, len(archived)
}
