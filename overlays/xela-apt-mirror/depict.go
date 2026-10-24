package main

import (
	"bytes"
	"encoding/json"
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

	jsonMu     sync.Mutex
	jsonTpl    string
	jsonProbed bool
	jsonSaved  int
	jsonDone   map[string]bool
	mirrDone   map[string]bool
	mirrBad    map[string]bool
}

// newArchiver initializes the depiction-JSON learning state
func (a *archiver) initJSON() {
	a.jsonDone = map[string]bool{}
	a.mirrDone = map[string]bool{}
	a.mirrBad = map[string]bool{}
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

// depict404Limit is how many hard 404s a single depiction host can answer
// with in one run before the run gives up on it entirely; guards dead
// upstreams from being hammered with thousands of guaranteed-404 requests
const depict404Limit = 15

// deadDepictionsPath is the persistent memo of depiction URLs that upstream
// answered 404/Gone; re-requesting them every sync would just spam dead hosts
func (a *archiver) deadDepictionsPath() string {
	return filepath.Join(a.repoDir, "_meta", "deadDepictions.json")
}

// loadDeadDepictions reads the memo; second return is whether the memo file
// existed (distinct from "empty")
func (a *archiver) loadDeadDepictions() (map[string]bool, bool) {
	raw, err := os.ReadFile(a.deadDepictionsPath())
	if err != nil {
		return map[string]bool{}, false
	}
	var dead map[string]bool
	if json.Unmarshal(raw, &dead) != nil {
		return map[string]bool{}, true
	}
	return dead, true
}

// saveDeadDepictions persists the memo; URLs keep coming back only via the
// canary re-check clearing it wholesale
func (a *archiver) saveDeadDepictions(dead map[string]bool) {
	if len(dead) == 0 {
		if err := os.Remove(a.deadDepictionsPath()); err != nil && !os.IsNotExist(err) {
			a.lg.Printf("depictions: dead memo remove: %v", err)
		}
		return
	}
	if err := os.MkdirAll(filepath.Join(a.repoDir, "_meta"), 0o755); err != nil {
		return
	}
	raw, err := json.MarshalIndent(dead, "", "  ")
	if err != nil {
		return
	}
	if err := writeAtomic(a.deadDepictionsPath(), raw); err != nil {
		a.lg.Printf("depictions: dead memo write: %v", err)
	}
}

// depictions archives every unique Depiction/SileoDepiction page as rendered
// HTML; returns url -> archived rel path for successfully archived URLs.
// Hard-404ed URLs are memoized on disk and skipped on later runs (with a
// one-request daily canary to detect upstream recovery), and a host that
// racks up depict404Limit 404s during a run is dropped for the rest of it
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
	dead, hadMemo := a.loadDeadDepictions()
	if len(dead) != 0 {
		// canary: one request instead of thousands; upstream recovery
		// reopens everything for this run and wipes the memo
		keys := make([]string, 0, len(dead))
		for k := range dead {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		canary := keys[0]
		if _, _, err := a.f.Fetch(canary); err == nil {
			a.lg.Printf("depictions: canary %s recovered upstream, retrying %d known-dead URLs", canary, len(dead))
			dead = map[string]bool{}
		} else if hadMemo {
			a.lg.Printf("depictions: skipping %d known-dead upstream URLs (canary still %v)", len(dead), err)
		}
	}
	var deadMu sync.Mutex
	// every access below goes through deadMu-dead/hostDead guards: the
	// job pool runs concurrently and Go maps fault on read/write races
	markDead := func(u string) { deadMu.Lock(); dead[u] = true; deadMu.Unlock() }
	isDead := func(u string) bool {
		deadMu.Lock()
		defer deadMu.Unlock()
		return dead[u]
	}
	hostStreak := map[string]int{}
	hostDead := map[string]bool{}
	hostGone := func(h string) bool {
		deadMu.Lock()
		defer deadMu.Unlock()
		return h != "" && hostDead[h]
	}
	bump404 := func(host string) bool {
		deadMu.Lock()
		defer deadMu.Unlock()
		if hostDead[host] {
			return true
		}
		hostStreak[host]++
		if hostStreak[host] >= depict404Limit {
			hostDead[host] = true
			a.lg.Printf("depictions: %s returned 404 on %d depictions; skipping the rest of them this run", host, hostStreak[host])
		}
		return hostDead[host]
	}
	if len(jobs) != 0 {
		a.lg.Printf("archiving %d depictions", len(jobs))
	}
	archived := map[string]string{}
	var mu sync.Mutex
	runPool(3, len(jobs), func(i int) error {
		j := jobs[i]
		if isDead(j.url) {
			return nil
		}
		host := hostOf(j.url)
		if hostGone(host) {
			markDead(j.url)
			return nil
		}
		rel := "_archive/depictions/" + sanitizeName(j.id) + "-" + sha256Hex([]byte(j.url))[:8] + ".html"
		dest := filepath.Join(a.repoDir, "_archive", "depictions", sanitizeName(j.id)+"-"+sha256Hex([]byte(j.url))[:8]+".html")
		body, _, err := a.f.Fetch(j.url)
		if err != nil || len(body) == 0 {
			if errors.Is(err, ErrNotFound) {
				markDead(j.url)
				bump404(host)
			}
			if err == nil {
				err = errShortBody
			}
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
		mu.Lock()
		archived[j.url] = rel
		mu.Unlock()
		return nil
	})
	if hadMemo || len(dead) != 0 {
		a.saveDeadDepictions(dead)
	}
	return archived, len(archived)
}
