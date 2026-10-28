package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strings"
	"sync"
)

var (
	// attr/srcset/og-content regexes capture the attribute name in
	// group 1 and the value in group 2 so callers can filter data-src
	// in code (RE2 has no lookbehind); the `[^-\w]` prefixes keep
	// lookalikes like data-srcset/data-content from matching
	attrDQRe   = regexp.MustCompile(`(?i)\b(src|href|poster|data-src)\s*=\s*"([^"]*)"`)
	attrSQRe   = regexp.MustCompile(`(?i)\b(src|href|poster|data-src)\s*=\s*'([^']*)'`)
	srcsetRe   = regexp.MustCompile(`(?i)(?:^|[^-\w])(srcset)\s*=\s*"([^"]*)"`)
	imgTagRe   = regexp.MustCompile(`(?i)<img\s[^>]*>`)
	ogImgRe    = regexp.MustCompile(`(?i)<meta\s[^>]*(?:property|name)\s*=\s*["']og:image["'][^>]*>`)
	cssURLRe   = regexp.MustCompile(`(?i)url\(\s*((?:'[^']*')|(?:"[^"]*")|(?:[^'")][^)]*))\s*\)`)
	ogContRe   = regexp.MustCompile(`(?i)(?:^|[^-\w])content\s*=\s*"([^"]*)"`)
	ogContSQRe = regexp.MustCompile(`(?i)(?:^|[^-\w])content\s*=\s*'([^']*)'`)
	// static-rendition transforms: SPA depictions never boot in a mirror
	// (build-time JS symbols, absolute publicPath chunk loads, live API
	// calls), and SSR'd images hide inside <noscript>, invisible whenever
	// scripting is enabled — so the sidecar strips scripts altogether
	scriptRe     = regexp.MustCompile(`(?is)<script\b[^>]*>.*?</script>`)
	scriptVoidRe = regexp.MustCompile(`(?i)<script\b[^>]*?/>`)
	noscriptRe   = regexp.MustCompile(`(?i)</?noscript(?:\s[^>]*)?>`)
)

var (
	errShortBody = errors.New("empty body")
)

// depictJsonShadows: known generated-repo JSON bootstrap conventions,
// "<id>" is replaced with the depiction's id query param
var depictJsonShadows = []string{
	"data/<id>/<id>.json",
	"data/<id>.json",
	"<id>.json",
}

// pageJSONRe detects inline-script JSON bootstrap pages worth probing
var pageJSONRe = regexp.MustCompile(`(?i)\.json`)

// json asset refs: page-relative image paths inside the depiction JSON
var jsonAssetRe = regexp.MustCompile(`"(?:[^"{}\\]*)\.(?:png|jpg|jpeg|gif|webp|svg|ico)"`)

// jsonLiteralRe finds literal *.json path refs (page-relative or absolute)
var jsonLiteralRe = regexp.MustCompile("(?i)['\"]([^'\"\\s]+\\.json)['\"]")

// assetLiteralRe finds literal relative image refs inside a page body
var assetLiteralRe = regexp.MustCompile("(?i)['\"]([^'\"\\s]+\\.(?:png|jpe?g|gif|webp|svg|ico))['\"]")

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
		add(m[2], true)
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

// extractImgCands collects cross-host image URLs referenced from a
// depiction body: <img src/srcset> (<picture>/<source> srcset included)
// plus og:image meta content. Same-host refs pass through the ordinary
// asset walk instead. Not collected: cross-host refs inside inline
// style="...url(...)" (or inline <style> blocks) — those stay hotlinked
// in the static rendition, same as unmirrored og:images
func extractImgCands(body []byte, pageURL string) []string {
	var vals []string
	add := func(raw string) {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			return
		}
		resolved, ok := resolveRef(pageURL, raw)
		if !ok || sameHost(resolved, pageURL) {
			return
		}
		vals = append(vals, resolved)
	}
	// per-tag scans: running the attr regexes inside each matched <img>
	// tag makes every attribute its own match, so a leading data-src
	// (RE2's leftmost match) can't shadow the real src. data-src is
	// JS-lazy and staticRendition strips scripts, so data-src images
	// never render in the sidecar — mirror only what shows
	for _, t := range imgTagRe.FindAllString(string(body), -1) {
		for _, a := range attrDQRe.FindAllStringSubmatch(t, -1) {
			if strings.EqualFold(a[1], "src") {
				add(a[2])
			}
		}
		for _, a := range attrSQRe.FindAllStringSubmatch(t, -1) {
			if strings.EqualFold(a[1], "src") {
				add(a[2])
			}
		}
	}
	// the srcset guard already excludes data-srcset above
	for _, m := range srcsetRe.FindAllStringSubmatch(string(body), -1) {
		for _, part := range strings.Split(m[2], ",") {
			add(strings.TrimSpace(strings.SplitN(strings.TrimSpace(part), " ", 2)[0]))
		}
	}
	for _, m := range ogImgRe.FindAllStringSubmatch(string(body), -1) {
		c := ogContRe.FindStringSubmatch(m[0])
		if c == nil {
			c = ogContSQRe.FindStringSubmatch(m[0])
		}
		if c != nil {
			add(c[1])
		}
	}
	return sortedSet(vals)
}

// keyedMutex is a per-URL lock: two depiction jobs fetching the same image
// serialize on it, so the second waits for the first's cache write instead
// of refetching (and double-counting) it
type keyedMutex struct {
	mu    sync.Mutex
	locks map[string]*sync.Mutex
}

func (k *keyedMutex) lock(key string) *sync.Mutex {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.locks == nil {
		k.locks = map[string]*sync.Mutex{}
	}
	if k.locks[key] == nil {
		k.locks[key] = new(sync.Mutex)
	}
	return k.locks[key]
}

// stripDynamic strips script elements and unwraps <noscript> so its
// server-rendered content becomes visible. Run on the asset-rewritten
// body before extracting image candidates: script-generated
// <img>-shaped strings would otherwise spawn pointless mirror fetches
// for images that never render in the sidecar
func stripDynamic(body []byte) []byte {
	out := scriptRe.ReplaceAll(body, nil)
	out = scriptVoidRe.ReplaceAll(out, nil)
	out = noscriptRe.ReplaceAll(out, nil)
	return out
}

// staticRendition points successfully mirrored image refs at the local
// copies (including og:image meta content) over a dynamically-stripped
// body. Called on the already asset-rewritten (and, for the sidecar,
// already stripDynamic'd) body so stylesheet/img refs inside it stay
// intact — stripping is idempotent either way
func staticRendition(body []byte, pageURL string, imgs map[string]string) []byte {
	return rewriteRefs(stripDynamic(body), pageURL, imgs, "../")
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
		for _, part := range strings.Split(g[2], ",") {
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
			return swapRef(m, g[2], strings.Join(rebuilt, ", "))
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
	// og:image meta content: c[1] quotes decide which content regex matched;
	// cross-host og:images localize through the static-rendition img map,
	// same-host ones only when already in the ordinary asset map
	out = ogImgRe.ReplaceAllStringFunc(out, func(m string) string {
		c := ogContRe.FindStringSubmatch(m)
		if c == nil {
			c = ogContSQRe.FindStringSubmatch(m)
			if c == nil {
				return m
			}
		}
		if v, ok := mapOnly(c[1]); ok {
			return swapRef(m, c[1], v)
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

	jsonMu     sync.Mutex
	jsonTpl    string
	jsonProbed bool
	jsonSaved  int
	jsonDone   map[string]bool
	mirrDone   map[string]bool
	mirrBad    map[string]bool

	imgCache *assetCache // cross-host depiction images, deduped run-wide
	imgFly   keyedMutex  // serializes first-time fetches of the same image URL
}

// initRun resets the per-run learning/dedup state
func (a *archiver) initRun() {
	a.jsonDone = map[string]bool{}
	a.mirrDone = map[string]bool{}
	a.mirrBad = map[string]bool{}
	a.imgCache = newAssetCache()
}

// depictID extracts the id query param from a depiction URL
func depictID(raw string) string {
	uu, err := url.Parse(raw)
	if err != nil {
		return ""
	}
	return uu.Query().Get("id")
}

// relToDir renders absurl's clean path relative to dirPath, or "" when it
// would escape the dir (traversal) or is unusable
func relToDir(dirPath, absurl string) string {
	uu, err := url.Parse(absurl)
	if err != nil {
		return ""
	}
	rel, err := filepath.Rel(path.Clean(dirPath), path.Clean(uu.Path))
	if err != nil || rel == "" || rel == "." || strings.HasPrefix(rel, "../") {
		return ""
	}
	return filepath.ToSlash(rel)
}

// relToPageDir wraps relToDir with the dir of a depiction page URL
func relToPageDir(pageURL, absurl string) string {
	uu, err := url.Parse(pageURL)
	if err != nil {
		return ""
	}
	return relToDir(path.Dir(uu.Path), absurl)
}

// jsonAssetVals walks a JSON document and returns page-relative image-path
// string values worth mirroring
func jsonAssetVals(body []byte) []string {
	var root interface{}
	if json.Unmarshal(body, &root) != nil {
		return nil
	}
	vals := []string{}
	var walk func(v interface{})
	walk = func(v interface{}) {
		switch tv := v.(type) {
		case string:
			if len(tv) > 4 && len(tv) < 300 && !strings.ContainsAny(tv, ":\\?{}") &&
				jsonAssetRe.MatchString(`"`+tv+`"`) {
				vals = append(vals, tv)
			}
		case []interface{}:
			for _, item := range tv {
				walk(item)
			}
		case map[string]interface{}:
			keys := make([]string, 0, len(tv))
			for k := range tv {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			for _, k := range keys {
				walk(tv[k])
			}
		}
	}
	walk(root)
	return sortedSet(vals)
}

// learnJSONTpl probes the known JSON bootstrap conventions once and remembers
// the working pattern ("data/<id>/<id>.json" etc) for the rest of the run;
// returns "" when no convention matches this repo
func (a *archiver) learnJSONTpl(pageURL, id string) string {
	a.jsonMu.Lock()
	tpl, probed := a.jsonTpl, a.jsonProbed
	a.jsonMu.Unlock()
	if probed && tpl == "" {
		return ""
	}
	if tpl != "" || probed {
		return tpl
	}
	for _, cand := range depictJsonShadows {
		candidate := strings.ReplaceAll(cand, "<id>", id)
		resolved, ok := resolveRef(pageURL, candidate)
		if !ok {
			continue
		}
		body, _, err := a.f.Fetch(resolved)
		if err != nil || !json.Valid(body) || !bytes.Contains(body, []byte(`"id"`)) {
			continue
		}
		a.jsonMu.Lock()
		a.jsonTpl = cand
		a.jsonMu.Unlock()
		return cand
	}
	a.jsonMu.Lock()
	a.jsonProbed = true
	a.jsonMu.Unlock()
	return ""
}

// mirrorJSON archives a JSON-bootstrapped depiction's data file at its
// upstream-relative path (so the page's own JS URL keeps resolving) plus
// literal page-relative refs from the page and the data; image refs fall
// back to repo-root resolution because generated depictions mix page-relative
// literals with repo-root JSON fields
func (a *archiver) mirrorJSON(pageURL, tpl, id string, pageBody []byte) {
	// literal refs inside the page inline JS (helper .json + resources/*.png|ico)
	for _, re := range []*regexp.Regexp{jsonLiteralRe, assetLiteralRe} {
		for _, ref := range pageLiteralRefs(pageBody, re) {
			if rURL, ok := resolveRef(pageURL, ref); ok {
				a.mirrorOne(rURL, ref)
			}
		}
	}
	candidate := strings.ReplaceAll(tpl, "<id>", id)
	resolved, ok := resolveRef(pageURL, candidate)
	if !ok {
		return
	}
	a.jsonMu.Lock()
	done := a.jsonDone[resolved]
	a.jsonDone[resolved] = true
	a.jsonMu.Unlock()
	if done {
		return
	}
	body, _, err := a.f.Fetch(resolved)
	if err != nil || !json.Valid(body) || !bytes.Contains(body, []byte(`"id"`)) {
		if err == nil {
			err = errors.New("not a depiction json")
		}
		a.eg.add("depiction-json", resolved, err)
		return
	}
	if rel := relToPageDir(pageURL, resolved); rel != "" {
		if err := writeAtomic(filepath.Join(a.repoDir, "_archive", "depictions", rel), body); err != nil {
			a.eg.add("depiction-json", resolved, err)
			return
		}
	}
	a.jsonMu.Lock()
	a.jsonSaved++
	a.jsonMu.Unlock()

	// image-ish refs inside the data: page-relative first, repo-root fallback
	for _, ref := range jsonAssetVals(body) {
		if strings.HasPrefix(ref, "../") {
			continue
		}
		a.jsonMu.Lock()
		done := a.mirrDone[ref]
		bad := a.mirrBad[ref]
		a.mirrDone[ref] = true
		a.jsonMu.Unlock()
		if done || bad {
			continue
		}
		var body2 []byte
		if rURL, ok := resolveRef(pageURL, ref); ok {
			body2, _, err = a.f.Fetch(rURL)
		}
		if err != nil || len(body2) == 0 {
			if rURL, ok := resolveRef(a.baseURL, ref); ok {
				body2, _, err = a.f.Fetch(rURL)
			} else {
				err = errors.New("not resolvable")
			}
		}
		if err != nil || len(body2) == 0 {
			if err == nil {
				err = errShortBody
			}
			a.jsonMu.Lock()
			a.mirrBad[ref] = true
			a.jsonMu.Unlock()
			a.eg.add("asset", ref, err)
			continue
		}
		if err := writeAtomic(filepath.Join(a.repoDir, "_archive", "depictions", ref), body2); err != nil {
			a.jsonMu.Lock()
			a.mirrBad[ref] = true
			a.jsonMu.Unlock()
			a.eg.add("asset", ref, err)
			continue
		}
		a.jsonMu.Lock()
		a.jsonSaved++
		a.jsonMu.Unlock()
	}
}

// mirrorOne fetches rURL and mirrors it at fileRel under _archive/depictions;
// deduped per run (including failures)
func (a *archiver) mirrorOne(rURL, fileRel string) {
	if fileRel == "" || strings.HasPrefix(fileRel, "../") {
		return
	}
	a.jsonMu.Lock()
	done := a.mirrDone[rURL]
	bad := a.mirrBad[rURL]
	a.mirrDone[rURL] = true
	a.jsonMu.Unlock()
	if done || bad {
		return
	}
	body, _, err := a.f.Fetch(rURL)
	if err != nil || len(body) == 0 {
		if err == nil {
			err = errShortBody
		}
		a.jsonMu.Lock()
		a.mirrBad[rURL] = true
		a.jsonMu.Unlock()
		a.eg.add("asset", rURL, err)
		return
	}
	if err := writeAtomic(filepath.Join(a.repoDir, "_archive", "depictions", fileRel), body); err != nil {
		a.jsonMu.Lock()
		a.mirrBad[rURL] = true
		a.jsonMu.Unlock()
		a.eg.add("asset", rURL, err)
		return
	}
	a.jsonMu.Lock()
	a.jsonSaved++
	a.jsonMu.Unlock()
}

// pageLiteralRefs extracts literal path strings matching re from a page body,
// keeping only recoverable page-relative ones
func pageLiteralRefs(body []byte, re *regexp.Regexp) []string {
	vals := []string{}
	for _, m := range re.FindAllStringSubmatch(string(body), -1) {
		ref := m[1]
		if strings.HasPrefix(ref, "../") || strings.Contains(ref, "//") {
			continue
		}
		vals = append(vals, ref)
	}
	return sortedSet(vals)
}

// depictJSON archives the JSON data + assets behind a JS-bootstrapped
// depiction page, learning the repo's template convention on the first hit
func (a *archiver) depictJSON(pageURL string, pageBody []byte) {
	id := depictID(pageURL)
	if id == "" {
		return
	}
	tpl := a.learnJSONTpl(pageURL, id)
	if tpl == "" {
		return
	}
	a.mirrorJSON(pageURL, tpl, id, pageBody)
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
	g := a.newDeadGuard("icons")
	if len(jobs) != 0 {
		a.lg.Printf("archiving %d icons", len(jobs))
	}
	dp := newProgress(a.lg, "icons", len(jobs))
	var mu sync.Mutex
	runPool(3, len(jobs), func(i int) error {
		defer dp.tick()
		url := jobs[i]
		if g.skip(url) {
			return nil
		}
		if g.hostGone(hostOf(url)) {
			return nil
		}
		body, _, err := a.f.Fetch(url)
		if err != nil || len(body) == 0 {
			if err == nil {
				err = errShortBody
			}
			g.fail(url, err)
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
	g.settle()
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

// depict404Limit is the per-run breaker threshold below
const depict404Limit = 15

// deadGuard memoizes per-kind what upstream refused to give: URLs answered
// 404/Gone (persistent URL memo, dead<Kind>.json) and hosts that are
// unreachable at the network level — connect/latency timeouts, refused,
// dead DNS (persistent host memo, dead<Kind>Hosts.json). Both canaries
// re-check one sample per run so upstream recovery reopens everything.
// Used for depictions and icons
type deadGuard struct {
	a        *archiver
	kind     string
	memoPath string
	hostPath string
	hadMemo  bool
	hadHosts bool

	mu         sync.Mutex
	dead       map[string]bool
	hostStreak map[string]int
	hostFails  map[string]int
	hostDead   map[string]bool
	hostSample map[string]string // host -> a reachable-once URL, for canaries
}

func (a *archiver) newDeadGuard(kind string) *deadGuard {
	capKind := func(s string) string { return strings.ToUpper(s[:1]) + s[1:] }
	g := &deadGuard{
		a:          a,
		kind:       kind,
		memoPath:   filepath.Join(a.repoDir, "_meta", "dead"+capKind(kind)+".json"),
		hostPath:   filepath.Join(a.repoDir, "_meta", "dead"+capKind(kind)+"Hosts.json"),
		dead:       map[string]bool{},
		hostStreak: map[string]int{},
		hostFails:  map[string]int{},
		hostDead:   map[string]bool{},
		hostSample: map[string]string{},
	}
	if raw, err := os.ReadFile(g.memoPath); err == nil {
		if json.Unmarshal(raw, &g.dead) == nil {
			g.hadMemo = true
		}
	}
	if raw, err := os.ReadFile(g.hostPath); err == nil {
		if json.Unmarshal(raw, &g.hostSample) == nil {
			g.hadHosts = true
			for h := range g.hostSample {
				g.hostDead[h] = true
			}
		}
	}
	if len(g.hostDead) != 0 {
		// host canary: one request per memoized host; recovery reopens
		// it. Any HTTP-level answer (200, 404, 403, ...) proves the
		// network path works — only a network-level failure keeps the
		// host memoized.
		hits, alive := 0, 0
		for _, h := range sortedKeys(g.hostSample) {
			url := g.hostSample[h]
			if _, _, err := a.f.Fetch(url); err != nil && !errors.Is(err, ErrNotFound) && !errors.Is(err, ErrLocked) {
				hits++
				continue
			}
			alive++
			a.lg.Printf("%s: canary %s answered, unmarking host", kind, url)
			delete(g.hostDead, h)
			delete(g.hostSample, h)
			delete(g.hostFails, h)
			delete(g.dead, url) // let a still-dead URL re-probe next run
		}
		if hits != 0 {
			a.lg.Printf("%s: skipping %d memoized-unreachable hosts; %d recovered", kind, hits, alive)
		}
	}
	if len(g.dead) != 0 {
		// url canary: one request instead of thousands; upstream recovery
		// reopens everything for this run and wipes the memo
		keys := make([]string, 0, len(g.dead))
		for k := range g.dead {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		canary := keys[0]
		if _, _, err := a.f.Fetch(canary); err == nil {
			a.lg.Printf("%s: canary %s recovered upstream, retrying %d known-dead URLs", kind, canary, len(g.dead))
			g.dead = map[string]bool{}
		} else {
			a.lg.Printf("%s: skipping %d known-dead upstream URLs (canary still %v)", kind, len(g.dead), err)
		}
	}
	return g
}

// skip reports whether this URL is memoized dead (and skips silently)
func (g *deadGuard) skip(u string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.dead[u]
}

// hostGone reports whether the host above the depict404Limit is dropped
func (g *deadGuard) hostGone(h string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	return h != "" && g.hostDead[h]
}

// fail records one failed fetch inside the guard: 404/Gone memoizes the
// URL and feeds the per-host 404 breaker; network-level failures
// (timeouts, refused, dead DNS) feed a second per-host breaker — that
// class of dead upstream never trips the 404 path, and each poisoned URL
// would otherwise burn ~6 minutes of retries per worker
func (g *deadGuard) fail(u string, err error) {
	if err == nil {
		return
	}
	host := hostOf(u)
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.hostDead[host] {
		return
	}
	switch {
	case errors.Is(err, ErrLocked):
		// auth/paywalled gating is per-URL and stable, like a 404 —
		// memoize the URL only, never the host (a 4xx itself proves the
		// network path is alive, and other URLs there may be reachable)
		g.dead[u] = true
	case errors.Is(err, ErrNotFound):
		// only the per-URL memo needs a 404; the hosts memo is reserved
		// for network-dead hosts, and a 404 itself proves the network is
		// alive — memoizing the host here could pin it dead forever on a
		// permanently-404ed sample
		g.dead[u] = true
		g.hostStreak[host]++
		if g.hostStreak[host] >= depict404Limit {
			g.hostDead[host] = true
			g.a.lg.Printf("%s: %s returned 404 on %d of them; skipping the rest this run", g.kind, host, g.hostStreak[host])
		}
	case isUnreachable(err):
		g.hostFails[host]++
		g.hostSample[host] = u
		if g.hostFails[host] >= depict404Limit {
			g.hostDead[host] = true
			delete(g.hostStreak, host)
			g.a.lg.Printf("%s: %s unreachable (timeouts/refused) on %d of them; skipping the rest this run and memoizing the host", g.kind, host, g.hostFails[host])
		}
	}
}

// isUnreachable reports whether a fetch error is a network-level failure
// (timeout, connection refused, no route, dead DNS) rather than an HTTP
// response; these signal dead or blackholed infrastructure, not per-URL
// 404s, and get breaker treatment through deadGuard.fail
func isUnreachable(err error) bool {
	var ne net.Error
	if errors.As(err, &ne) && ne.Timeout() {
		return true
	}
	var oe *net.OpError
	if errors.As(err, &oe) {
		return true
	}
	var de *net.DNSError
	if errors.As(err, &de) {
		return true
	}
	return false
}

// settle persists the memos (dropping files when a store is empty)
func (g *deadGuard) settle() {
	if g.hadMemo || len(g.dead) != 0 {
		if len(g.dead) == 0 {
			if err := os.Remove(g.memoPath); err != nil && !os.IsNotExist(err) {
				g.a.lg.Printf("%s: dead memo remove: %v", g.kind, err)
			}
		} else if err := g.writeMemo(g.memoPath, g.dead); err != nil {
			g.a.lg.Printf("%s: dead memo write: %v", g.kind, err)
		}
	}
	if g.hadHosts || len(g.hostSample) != 0 {
		if len(g.hostSample) == 0 {
			if err := os.Remove(g.hostPath); err != nil && !os.IsNotExist(err) {
				g.a.lg.Printf("%s: dead hosts memo remove: %v", g.kind, err)
			}
		} else if err := g.writeMemo(g.hostPath, g.hostSample); err != nil {
			g.a.lg.Printf("%s: dead hosts memo write: %v", g.kind, err)
		}
	}
}

func (g *deadGuard) writeMemo(path string, val any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	raw, err := json.MarshalIndent(val, "", "  ")
	if err != nil {
		return err
	}
	return writeAtomic(path, raw)
}

// archivedDepiction bundles what got archived for one depiction URL
type archivedDepiction struct {
	rel    string // archived depiction engine page, repo-relative
	static string // script-stripped, image-local sidecar, repo-relative
}

// mirrorImages fetches a depiction body's cross-host images into
// _archive/img (deduped run-wide via imgCache — pages sharing an image
// fetch it once; failures skip silently and only re-count) and answers the
// url -> "img/name" ref map used to localize the static rendition
func (a *archiver) mirrorImages(g *deadGuard, body []byte, pageURL string) (map[string]string, int) {
	cands := extractImgCands(body, pageURL)
	saved := 0
	res := map[string]string{}
	if len(cands) == 0 {
		return res, 0
	}
	var mu sync.Mutex
	runPool(3, len(cands), func(i int) error {
		raw := cands[i]
		if g.skip(raw) {
			return nil
		}
		if g.hostGone(hostOf(raw)) {
			return nil
		}
		// single-flight on the URL: a concurrent page wanting the same
		// image waits here and then takes the cache hit, so the image
		// fetches once and is counted once
		unlock := a.imgFly.lock(raw)
		unlock.Lock()
		defer unlock.Unlock()
		if name, failed := a.imgCache.lookup(raw); name != "" || failed != "" {
			if name == "" {
				// already failed earlier this run; keep its error counted
				a.eg.add("image", raw, errors.New(failed))
				return nil
			}
			mu.Lock()
			res[raw] = name
			mu.Unlock()
			return nil
		}
		name, err := a.fetchImage(raw)
		if err != nil {
			a.imgCache.fail(raw, err.Error())
			g.fail(raw, err)
			return nil
		}
		ref := "img/" + name
		a.imgCache.remember(raw, ref)
		mu.Lock()
		// first-time saves only: cache hits below don't recount
		res[raw] = ref
		saved++
		mu.Unlock()
		return nil
	})
	return res, saved
}

// fetchImage archives one image into _archive/img with the icon naming
// scheme (basename + content hash + guessed ext); empty name on error
func (a *archiver) fetchImage(raw string) (string, error) {
	body, _, err := a.f.Fetch(raw)
	if err != nil || len(body) == 0 {
		if err == nil {
			err = errShortBody
		}
		a.eg.add("image", raw, err)
		return "", err
	}
	name := sanitizeName(assetBaseName(raw)) + "_" + sha256Hex(body)[:8] + guessImageExt(raw)
	if err := writeAtomic(filepath.Join(a.repoDir, "_archive", "img", name), body); err != nil {
		a.eg.add("image", raw, err)
		return "", err
	}
	return name, nil
}

// depictions archives every unique Depiction/SileoDepiction page as rendered
// HTML plus a script-stripped static rendition, and mirrors the body's
// cross-host images into _archive/img. Returns url -> archived info.
// Hard-404ed URLs are memoized on disk and skipped on later runs (with a
// one-request daily canary to detect upstream recovery), and a host that
// racks up depict404Limit 404s during a run is dropped for the rest of it
// depictionVersion gates the depiction skip-cache: bump whenever the
// depiction fetcher/archiver behavior changes (rewriting, image
// mirroring, stripDynamic, error classification, ...) so every repo
// re-fetches once and then rebuilds its skip state
const depictionVersion = 1

// depictVersionsCap bounds how many package versions are remembered per
// depiction URL (generic shared depictions would otherwise accumulate
// versions forever); it is generous — every entry is a short string — so
// real-world version sets never hit it; beyond the cap the oldest entries
// drop, which costs a re-fetch of that URL
const depictVersionsCap = 512

// depictState is the repo-persistent depiction skip-cache: per URL, which
// package versions were already archived. The cached page is trusted
// only when its artifacts also exist on disk
type depictState struct {
	Version int                      `json:"version"`
	URLs    map[string]*depictVersed `json:"urls,omitempty"`
}

type depictVersed struct {
	Versions []string `json:"versions"`
	Static   bool     `json:"static,omitempty"`
}

// depictStatePath names the repo's skip-cache file
func (a *archiver) depictStatePath() string {
	return filepath.Join(a.repoDir, "_meta", "depictions.state")
}

// loadDepictState reads the skip-cache, returning an empty one when it is
// missing, unreadable or produced by a different depictionVersion
func (a *archiver) loadDepictState() *depictState {
	st := &depictState{Version: depictionVersion}
	if raw, err := os.ReadFile(a.depictStatePath()); err == nil {
		var seen depictState
		if json.Unmarshal(raw, &seen) == nil && seen.Version == depictionVersion {
			return &seen
		}
	}
	return st
}

// saveDepictState persists the skip-cache (no-op while it stays empty)
func (a *archiver) saveDepictState(st *depictState) {
	if len(st.URLs) == 0 {
		return
	}
	raw, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		a.lg.Printf("depictions: state marshal: %v", err)
		return
	}
	if err := writeAtomic(a.depictStatePath(), raw); err != nil {
		a.lg.Printf("depictions: state write: %v", err)
	}
}

// versCovered reports whether every job version is already recorded and
// the archived static sidecar was intact when they were (a failed static
// rendition stays Static=false so the URL refetches instead of serving a
// stale sidecar)
func versCovered(st *depictState, url string, versions []string) bool {
	ent := st.URLs[url]
	if ent == nil || !ent.Static {
		return false
	}
	for _, v := range versions {
		if !slices.Contains(ent.Versions, v) {
			return false
		}
	}
	return true
}

// versRecord merges one job's versions into the entry, evicting oldest
// entries beyond depictVersionsCap
func versRecord(st *depictState, url string, versions []string, static bool) {
	if st.URLs == nil {
		st.URLs = map[string]*depictVersed{}
	}
	ent := st.URLs[url]
	if ent == nil {
		ent = &depictVersed{Static: static}
		st.URLs[url] = ent
	} else {
		ent.Static = static
	}
	for _, v := range versions {
		if slices.Contains(ent.Versions, v) {
			continue
		}
		ent.Versions = append(ent.Versions, v)
		if len(ent.Versions) > depictVersionsCap {
			ent.Versions = ent.Versions[1:]
		}
	}
}

// depictions archives every package's depiction page (rewritten archive
// copy + dynamic-stripped static sidecar + its assets/images). Skip
// caching avoids re-downloading pages already archived at the current
// depictionVersion for unchanged package versions; a version bump (or a
// changed depiction URL) re-fetches
func (a *archiver) depictions(entries []PkgEntry) (map[string]archivedDepiction, int, int) {
	// unique URLs in first-seen order, every package version seen per URL
	// (a package-version bump must re-fetch even with an unchanged URL),
	// plus the first id, which names the deterministic artifact
	type depJob struct {
		id, url  string
		versions []string
	}
	var order []string
	urlVers := map[string][]string{}
	firstID := map[string]string{}
	for _, e := range entries {
		for _, key := range []string{"depiction", "sileodepiction"} {
			raw := strings.TrimSpace(e.Get(key))
			if raw == "" || e.ID() == "" {
				continue
			}
			resolved, ok := resolveRef(a.baseURL, raw)
			if !ok {
				continue
			}
			if _, fresh := firstID[resolved]; !fresh {
				firstID[resolved] = e.ID()
				order = append(order, resolved)
			}
			if v := e.Version(); v != "" && !slices.Contains(urlVers[resolved], v) {
				urlVers[resolved] = append(urlVers[resolved], v)
			}
		}
	}
	jobs := make([]depJob, 0, len(order))
	for _, u := range order {
		jobs = append(jobs, depJob{id: firstID[u], url: u, versions: urlVers[u]})
	}
	g := a.newDeadGuard("depictions")
	ig := a.newDeadGuard("images")
	skips := a.loadDepictState()
	if len(jobs) != 0 {
		a.lg.Printf("archiving %d depictions", len(jobs))
	}
	dp := newProgress(a.lg, "depictions", len(jobs))
	archived := map[string]archivedDepiction{}
	var mu sync.Mutex
	imgsSaved := 0
	reused := 0
	skipped := 0
	refetched := 0
	runPool(3, len(jobs), func(i int) error {
		defer dp.tick()
		j := jobs[i]
		if g.skip(j.url) || g.hostGone(hostOf(j.url)) {
			mu.Lock()
			skipped++
			mu.Unlock()
			return nil
		}
		rel := "_archive/depictions/" + sanitizeName(j.id) + "-" + sha256Hex([]byte(j.url))[:8] + ".html"
		staticRel := strings.TrimSuffix(rel, ".html") + "-static.html"
		dest := filepath.Join(a.repoDir, rel)
		staticDest := filepath.Join(a.repoDir, staticRel)
		// skip-cache hit at the current depictionVersion: both artifacts
		// present and non-empty, and no package version is new — serve
		// straight from disk without touching upstream. mu guards the
		// shared skip-state against the other workers' versRecord calls.
		mu.Lock()
		cacheHit := versCovered(skips, j.url, j.versions) &&
			diskSize(dest) != 0 && diskSize(staticDest) != 0
		if cacheHit {
			reused++
			archived[j.url] = archivedDepiction{rel: rel, static: staticRel}
		}
		mu.Unlock()
		if cacheHit {
			return nil
		}
		mu.Lock()
		refetched++
		mu.Unlock()
		body, _, err := a.f.Fetch(j.url)
		if err != nil || len(body) == 0 {
			if err == nil {
				err = errShortBody
			}
			g.fail(j.url, err)
			a.eg.add("depiction", j.url, err)
			return nil
		}
		if pageJSONRe.Match(body) {
			a.depictJSON(j.url, body)
		}
		assets := a.fetchAssets(extractAssetCands(body, j.url), 0)
		rewritten := rewriteRefs(body, j.url, assets, "../assets/")
		if err := writeAtomic(dest, rewritten); err != nil {
			a.eg.add("depiction", j.url, err)
			return nil
		}
		// cross-host images + the static view only matter once the page
		// itself is in the archive; candidates come from the stripped
		// body (scripts gone, noscript unwrapped) so they're exactly
		// what the sidecar can render
		stripped := stripDynamic(rewritten)
		imgMap, n := a.mirrorImages(ig, stripped, j.url)
		mu.Lock()
		imgsSaved += n
		mu.Unlock()
		static := staticRendition(stripped, j.url, imgMap)
		if err := writeAtomic(staticDest, static); err != nil {
			a.eg.add("static-rendition", j.url, err)
			mu.Lock()
			versRecord(skips, j.url, j.versions, false)
			archived[j.url] = archivedDepiction{rel: rel}
			mu.Unlock()
			return nil
		}
		mu.Lock()
		versRecord(skips, j.url, j.versions, true)
		archived[j.url] = archivedDepiction{rel: rel, static: staticRel}
		mu.Unlock()
		return nil
	})
	if reused != 0 {
		a.lg.Printf("depictions: %d fetched, %d dead-skipped, %d reused from skip cache",
			refetched, skipped, reused)
	}
	a.saveDepictState(skips)
	g.settle()
	ig.settle()
	return archived, len(archived), imgsSaved
}

// diskSize reports the size of an existing regular file, else 0
func diskSize(p string) int64 {
	fi, err := os.Stat(p)
	if err != nil || !fi.Mode().IsRegular() {
		return 0
	}
	return fi.Size()
}
