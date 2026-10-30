package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type MissingDeb struct {
	File   string `json:"file"`
	URL    string `json:"url,omitempty"` // set: Filename is an external absolute URL
	Reason string `json:"reason"`
	Size   string `json:"size,omitempty"`
	Sha    string `json:"sha,omitempty"`
	Md5    string `json:"md5,omitempty"`
}

type RepoManifest struct {
	Name          string            `json:"name"`
	URL           string            `json:"url"`
	Distribution  string            `json:"distribution,omitempty"`
	Mirror        string            `json:"mirror"`
	Status        string            `json:"status"`
	Error         string            `json:"error,omitempty"`
	Updated       string            `json:"updated"`
	LastAttempt   string            `json:"attempted"`
	Release       map[string]string `json:"release,omitempty"`
	Indexes       []string          `json:"indexes,omitempty"`
	Unique        int               `json:"uniquePackages"`
	Versions      int               `json:"packageVersions"`
	Debs          int               `json:"debs"`
	LogicalSize   int64             `json:"logicalBytes"`
	OK            int               `json:"debsOk"`
	Missing       []MissingDeb      `json:"missing,omitempty"`
	Locked        []MissingDeb      `json:"locked,omitempty"`
	Icons         int               `json:"icons"`
	Depictions    int               `json:"depictions"`
	ArchivedBytes int64             `json:"archivedBytes,omitempty"` // filled at landing render, not by syncOne
}

type DepictRef struct {
	Original string `json:"original"`
	Archived string `json:"archived,omitempty"`
	Static   string `json:"static,omitempty"`
}

type BrowserVersion struct {
	Version    string      `json:"version"`
	Status     string      `json:"status"`
	Reason     string      `json:"reason,omitempty"`
	Size       int64       `json:"size"`
	Deb        string      `json:"deb,omitempty"`
	Shasum     string      `json:"shasum,omitempty"`
	Author     string      `json:"author,omitempty"`
	Compat     string      `json:"compat,omitempty"`
	Depictions []DepictRef `json:"depictions,omitempty"`
}

type BrowserPackage struct {
	ID          string           `json:"id"`
	Name        string           `json:"name,omitempty"`
	Section     string           `json:"section,omitempty"`
	Description string           `json:"description,omitempty"`
	Homepage    string           `json:"homepage,omitempty"`
	Icon        string           `json:"icon,omitempty"`
	Versions    []BrowserVersion `json:"versions"`
}

type BrowserData struct {
	Name     string            `json:"name"`
	Upstream string            `json:"upstream"`
	Mirror   string            `json:"mirror"`
	Release  map[string]string `json:"release,omitempty"`
	Synced   string            `json:"synced"`
	Unique   int               `json:"uniquePackages"`
	Packages []BrowserPackage  `json:"packages"`
}

type debTask struct {
	file string
	url  string // set when Filename is an absolute URL (downloaded directly)
	size string
	sha  string
	md5  string
}

type debStatus struct {
	task   debTask
	state  string // ok | missing | locked
	reason string
}

func loadManifest(dataDir, name string) *RepoManifest {
	raw, err := os.ReadFile(filepath.Join(dataDir, name, "_meta", "manifest.json"))
	if err != nil {
		return nil
	}
	var m RepoManifest
	if err := json.Unmarshal(raw, &m); err != nil {
		log.Printf("[%s] corrupt manifest ignored: %v", name, err)
		return nil
	}
	return &m
}

func writeManifest(dataDir string, man *RepoManifest) {
	if man.Missing == nil {
		man.Missing = []MissingDeb{}
	}
	if man.Locked == nil {
		man.Locked = []MissingDeb{}
	}
	raw, err := json.MarshalIndent(man, "", "  ")
	if err != nil {
		log.Printf("[%s] manifest marshal: %v", man.Name, err)
		return
	}
	if err := os.MkdirAll(filepath.Join(dataDir, man.Name, "_meta"), 0o755); err != nil {
		log.Printf("[%s] manifest dir: %v", man.Name, err)
		return
	}
	if err := writeAtomic(man.manifestPath(dataDir), raw); err != nil {
		log.Printf("[%s] manifest write: %v", man.Name, err)
	}
}

func (m *RepoManifest) manifestPath(dataDir string) string {
	return filepath.Join(dataDir, m.Name, "_meta", "manifest.json")
}

func poolKeyOf(t debTask) string {
	if h := normalizeHex(t.sha); h != "" {
		return h
	}
	if h := normalizeHex(t.md5); h != "" {
		return "md5-" + h
	}
	return ""
}

func sizeFits(got int64, want string) bool {
	// an absent Size field imposes no constraint; only a *present but*
	// unparseable size fails closed
	if strings.TrimSpace(want) == "" {
		return true
	}
	w, ok := parseSize(want)
	if !ok {
		return false
	}
	return w == 0 || got == w
}

func mustParseSize(s string) int64 {
	n, _ := parseSize(s)
	return n
}

func verifyIndex(body []byte, entry ReleaseEntry) error {
	if entry.Path == "" {
		return nil
	}
	if want, ok := parseSize(entry.Size); ok && want > 0 && int64(len(body)) != want {
		return fmt.Errorf("size mismatch: got %d want %d", len(body), want)
	}
	if entry.Sha != "" {
		want := normalizeHex(entry.Sha)
		if want != "" {
			switch len(want) {
			case 64:
				if sha256Hex(body) != want {
					return fmt.Errorf("sha256 mismatch")
				}
			case 128:
				if sha512Hex(body) != want {
					return fmt.Errorf("sha512 mismatch")
				}
			default:
				return fmt.Errorf("unsupported sha length %d", len(want))
			}
		}
	}
	if entry.Md5 != "" {
		want := normalizeHex(entry.Md5)
		if want != "" && md5Hex(body) != want {
			return fmt.Errorf("md5 mismatch")
		}
	}
	return nil
}

func mirrorURL(publicURL, name string) string {
	return strings.TrimRight(publicURL, "/") + "/" + name
}

// keepServing writes the last manifest back untouched so stale content keeps
// being served when an upstream dies
func keepServing(dataDir string, old *RepoManifest, now time.Time) *RepoManifest {
	old.LastAttempt = formatTime(now)
	if old.Status == statusSynced || old.Status == "" {
		old.Status = statusStale
	}
	writeManifest(dataDir, old)
	return old
}

func runPool(n, count int, fn func(i int) error) []error {
	if n <= 0 {
		n = 1
	}
	errs := make([]error, count)
	var wg sync.WaitGroup
	jobs := make(chan int, count)
	for i := 0; i < count; i++ {
		jobs <- i
	}
	close(jobs)
	for w := 0; w < n; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				errs[i] = fn(i)
			}
		}()
	}
	wg.Wait()
	return errs
}

// progress logs time-gated completion counts for a countable phase
const progressInterval = 15 * time.Second

type progress struct {
	lg    *log.Logger
	label string
	total int
	mu    sync.Mutex
	done  int
	last  time.Time
}

func newProgress(lg *log.Logger, label string, total int) *progress {
	return &progress{lg: lg, label: label, total: total, last: time.Now()}
}

// tick records one completed item, logging the running count at most once
// per progressInterval
func (p *progress) tick() {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.done++
	if time.Since(p.last) < progressInterval {
		return
	}
	p.lg.Printf("%s %d/%d", p.label, p.done, p.total)
	p.last = time.Now()
}

func joinRawURL(base, rel string) string {
	segs := strings.Split(strings.TrimPrefix(rel, "./"), "/")
	esc := make([]string, len(segs))
	for i, s := range segs {
		esc[i] = (&url.URL{Path: s}).String()
	}
	return base + strings.Join(esc, "/")
}

// externalFilenameURL reports whether a Packages Filename is an absolute
// http(s) URL (some repos — jjolano, ... — reference GitHub release debs
// directly instead of a repo-relative pool path). Returns the cleaned URL
func externalFilenameURL(p string) (string, bool) {
	raw := strings.TrimSpace(p)
	if strings.ContainsAny(raw, " \t\r\n") {
		return "", false
	}
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" || (u.Scheme != "https" && u.Scheme != "http") {
		return "", false
	}
	return u.String(), true
}

// externalDebPath names the canonical mirror-local deb target for an
// external-URL filename: checksum-keyed into the shared pool when the
// entry provides one, else a stable digest of the URL
func externalDebPath(t debTask) string {
	if key := poolKeyOf(t); key != "" {
		return "pool/external/" + key + ".deb"
	}
	return "pool/external/url-" + sha256Hex([]byte(t.url))[:12] + ".deb"
}

// canonicalDebPath resolves one entry's Filename into a repo-relative
// local path plus, for external URLs, the raw URL to download from
func canonicalDebPath(e PkgEntry) (localPath, rawURL string, ok bool) {
	fn := e.Filename()
	if fn == "" {
		return "", "", false
	}
	if u, isURL := externalFilenameURL(fn); isURL {
		t := debTask{url: u, sha: e.Get("sha256"), md5: e.Get("md5sum")}
		return externalDebPath(t), u, true
	}
	c, okRel := safeRel(fn)
	return c, "", okRel
}

// rewriteExternalFilenames rewrites Filename lines that reference external
// absolute URLs to their canonical mirror-local paths in an index body.
// map keys are the upstream Filename field values verbatim
func rewriteExternalFilenames(body []byte, canon map[string]string) []byte {
	if len(canon) == 0 {
		return body
	}
	text := string(body)
	norm := strings.ReplaceAll(text, "\r\n", "\n")
	if norm != text {
		text = norm
	}
	lines := strings.Split(text, "\n")
	changed := false
	for i, line := range lines {
		if !strings.HasPrefix(strings.ToLower(line), "filename:") {
			continue
		}
		trim := strings.TrimSpace(line[len("filename:"):])
		// rewrite every Filename line whose upstream value is external
		if c, ok := canon[trim]; ok {
			lines[i] = "Filename: " + c
			changed = true
		}
	}
	if !changed {
		return body
	}
	return []byte(strings.Join(lines, "\n"))
}

// mirrorIndexBody is the store-time counterpart of the external-Filename
// rewrite: for one fetched index it decides what is mirrored and whether
// the Release checksums for its path must be recomputed.
//
//   - undecodable, or the rewrite would have to change its bytes and the
//     stdlib cannot regenerate its format: not mirrored at all (stash
//     false) — the caller also drops it from the Release checksum lists
//   - untouched by the rewrite (no external-URL Filenames): the upstream
//     bytes are stored verbatim (edited false), keeping the upstream
//     checksum lines in the Release valid. An untouched index must never
//     be hash-blessed by the mirror, even when its upstream sums failed
//     verification — that would make a mirror-local rewrite of apt's
//     fail-closed behavior on internally inconsistent upstream metadata
//   - otherwise: the rewritten body re-encoded for its path, edited true
func mirrorIndexBody(p string, raw []byte, canon map[string]string) (out []byte, stash, edited bool) {
	decoded, err := decodeIndex(raw)
	if err != nil {
		return nil, false, false // undecodable: cannot rewrite
	}
	editedBody := rewriteExternalFilenames(decoded, canon)
	if bytes.Equal(editedBody, decoded) {
		// no external-URL Filenames: upstream bytes verbatim
		return raw, true, false
	}
	enc, editable := indexReencode(p, editedBody)
	if !editable {
		return nil, false, false // stdlib cannot regenerate this format
	}
	return enc, true, true
}

func safeRel(p string) (string, bool) {
	if p == "" {
		return "", false
	}
	c := filepath.Clean(strings.TrimPrefix(p, "./"))
	if c == "." || c == ".." || strings.HasPrefix(c, "../") || strings.HasPrefix(c, "/") {
		return "", false
	}
	base := c
	if i := strings.IndexAny(c, `/\`); i >= 0 {
		base = c[:i]
	}
	for _, reserved := range []string{"_archive", "_meta", "_pool"} {
		if base == reserved {
			return "", false
		}
	}
	return c, true
}

func poolDir(dataDir string) string { return filepath.Join(dataDir, "_pool") }

// retryTask rebuilds a debTask from a manifest missing/locked record;
// md.URL (external-Filename support) restores direct-URL downloads, older
// manifests (missing the field) survive as plain-path attempts. The stored
// path is re-validated with the same rules fresh-plan entries pass: records
// are self-written from validated plans, but a corrupt or hand-edited
// manifest must not plan writes outside the repo root
func retryTask(md MissingDeb) (debTask, bool) {
	if _, ok := safeRel(md.File); !ok {
		return debTask{}, false
	}
	task := debTask{file: md.File, size: md.Size, sha: md.Sha, md5: md.Md5}
	if md.URL != "" {
		u, isURL := externalFilenameURL(md.URL)
		if !isURL {
			return debTask{}, false
		}
		task.url = u
	}
	return task, true
}

func syncOne(cfg *Config, repo RepoConfig, now time.Time) *RepoManifest {
	name := repo.Name
	dataDir := cfg.DataDir
	repoDir := filepath.Join(dataDir, name)
	baseURL := strings.TrimRight(repo.URL, "/") + "/"
	branchBase := baseURL
	distRel := ""
	if repo.Distribution != "" {
		distRel = "dists/" + repo.Distribution + "/"
		branchBase = baseURL + distRel
	}
	// fileRel combines a branch-relative (Packages-referenced) path with the
	// distribution prefix so it can be fetched/stored repo-root-relative
	fileRel := func(p string) string { return distRel + p }
	logger := log.New(activityWriter{os.Stderr}, "["+name+"] ", log.LstdFlags)
	logger.Printf("starting sync")
	os.MkdirAll(repoDir, 0o755)
	os.MkdirAll(poolDir(dataDir), 0o755)

	man := &RepoManifest{
		Name:         name,
		URL:          repo.URL,
		Distribution: repo.Distribution,
		Mirror:       mirrorURL(cfg.PublicURL, name),
		LastAttempt:  formatTime(now),
	}
	old := loadManifest(dataDir, name)

	f := NewFetcher(repo.Insecure)
	// the operator-configured upstream (possibly a LAN host) is exempt from
	// internal-host screening; everything derived from repo content —
	// external-Filename debs, icons, depictions — stays screened
	if u, errP := url.Parse(repo.URL); errP == nil {
		f.allowHost(u.Host)
	}
	finish := func(status string) {
		man.Status = status
		writeManifest(dataDir, man)
	}

	relBody, _, relErr := f.Fetch(branchBase + "Release")
	if relErr != nil {
		if old == nil {
			man.Error = relErr.Error()
			finish(statusFailed)
			return man
		}
		logger.Printf("metadata unreachable, keeping last state: %v", relErr)
		return keepServing(dataDir, old, now)
	}
	ri := parseRelease(relBody)
	man.Release = map[string]string{
		"origin":        ri.Get("origin"),
		"label":         ri.Get("label"),
		"description":   ri.Get("description"),
		"suite":         ri.Get("suite"),
		"codename":      ri.Get("codename"),
		"date":          ri.Get("date"),
		"version":       ri.Get("version"),
		"architectures": ri.Get("architectures"),
		"components":    ri.Get("components"),
	}

	extras := map[string][]byte{}
	// sigAbsent marks signed metadata confirmed absent upstream (404/410).
	// Any other fetch failure reads as "unknown": flipping the Filename
	// rewrite on based on a transient error would pair rewritten indexes
	// with a stale signed file still stored from an earlier sync
	sigAbsent := map[string]bool{}
	for _, p := range []string{"InRelease", "Release.gpg", "Release.key", "CydiaIcon.png", "CydiaIcon.svg"} {
		body, _, err := f.Fetch(joinRawURL(branchBase, p))
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				sigAbsent[p] = true
			}
			continue
		}
		extras[p] = body
	}

	listed, probes := discovery(ri, distRel != "")
	paths := append(append([]string{}, listed...), probes...)
	bodies := make([][]byte, len(paths))
	runPool(4, len(paths), func(i int) error {
		body, _, err := f.Fetch(joinRawURL(branchBase, paths[i]))
		if err == nil {
			bodies[i] = body
		}
		return nil
	})
	fetched := map[string][]byte{}
	for i, p := range paths {
		if bodies[i] != nil {
			fetched[p] = bodies[i]
		}
	}
	if len(fetched) == 0 {
		if old == nil {
			man.Error = "no Packages indexes found"
			finish(statusFailed)
			return man
		}
		logger.Printf("no indexes reachable, keeping last state")
		return keepServing(dataDir, old, now)
	}

	indexPaths := make([]string, 0, len(fetched))
	verified := map[string]bool{}
	var pkgEntries []PkgEntry
	seenContent := map[string]bool{}
	seenEntry := map[string]bool{}
	for _, p := range sortedKeys(fetched) {
		if ri != nil && ri.HasChecksums {
			if err := verifyIndex(fetched[p], ri.Entries[p]); err != nil {
				logger.Printf("index %s failed verification: %v", p, err)
				continue
			}
		}
		indexPaths = append(indexPaths, p)
		verified[p] = true
		decoded, err := decodeIndex(fetched[p])
		if err != nil {
			logger.Printf("decode %s: %v", p, err)
			continue
		}
		decodedKey := sha256Hex(decoded)
		if seenContent[decodedKey] {
			continue
		}
		seenContent[decodedKey] = true
		for _, e := range parsePackages(decoded) {
			entryKey := e.ID() + "\x00" + e.Version() + "\x00" + e.Filename()
			if seenEntry[entryKey] {
				continue
			}
			seenEntry[entryKey] = true
			pkgEntries = append(pkgEntries, e)
		}
	}
	if len(pkgEntries) == 0 {
		if old == nil {
			man.Error = "no package entries parsed from indexes"
			finish(statusFailed)
			return man
		}
		logger.Printf("no package entries parsed, keeping last state")
		return keepServing(dataDir, old, now)
	}
	man.Versions = len(pkgEntries)
	man.Indexes = indexPaths
	logger.Printf("release ok: %d indexes, %d package versions", len(indexPaths), len(pkgEntries))

	plan := map[string]debTask{}
	var order []string
	// external-URL Filenames rewrite canon: upstream Filename field value
	// verbatim -> canonical mirror-local path; drives both the deb plan
	// and the mirrored-index Filename rewrite
	canon := map[string]string{}
	for _, e := range pkgEntries {
		fn := e.Filename()
		if fn == "" {
			continue
		}
		task := debTask{size: e.Get("size"), sha: e.Get("sha256"), md5: e.Get("md5sum")}
		if u, isURL := externalFilenameURL(fn); isURL {
			task.url = u
			task.file = externalDebPath(task)
			canon[e.Get("filename")] = task.file
		} else if c, ok := safeRel(fn); ok {
			task.file = c
		} else {
			logger.Printf("unsafe filename %q skipped", fn)
			continue
		}
		if _, dup := plan[task.file]; dup {
			continue
		}
		plan[task.file] = task
		order = append(order, task.file)
	}
	if old != nil {
		present := map[string]bool{}
		for _, c := range order {
			present[c] = true
		}
		// replay last run's missing/locked debTasks; manifests written
		// with external-URL support carry the URL field (retryTask
		// restores direct-URL downloads), older ones have canonical (or
		// legacy path) file strings only and fall back to a plain-path
		// attempt when they are not also in the fresh plan
		retry := func(list []MissingDeb) {
			for _, md := range list {
				if !present[md.File] {
					present[md.File] = true
					task, ok := retryTask(md)
					if !ok {
						continue
					}
					plan[task.file] = task
					order = append(order, task.file)
				}
			}
		}
		retry(old.Missing)
		retry(old.Locked)
	}
	sort.Strings(order)

	statuses := make([]debStatus, len(order))
	for i := range order {
		statuses[i] = debStatus{task: plan[order[i]], state: statusOK}
	}
	logger.Printf("downloading %d debs", len(order))
	dp := newProgress(logger, "debs", len(order))
	runPool(4, len(order), func(i int) error {
		ensureDeb(f, baseURL, repoDir, poolDir(dataDir), &statuses[i])
		dp.tick()
		return nil
	})

	fileStates := map[string]debStatus{}
	man.Missing, man.Locked = []MissingDeb{}, []MissingDeb{}
	for i := range order {
		s := statuses[i]
		fileStates[s.task.file] = s
		switch s.state {
		case statusMissing:
			man.Missing = append(man.Missing, MissingDeb{File: s.task.file, URL: s.task.url, Reason: s.reason, Size: s.task.size, Sha: s.task.sha, Md5: s.task.md5})
		case statusLocked:
			man.Locked = append(man.Locked, MissingDeb{File: s.task.file, URL: s.task.url, Reason: s.reason, Size: s.task.size, Sha: s.task.sha, Md5: s.task.md5})
		default:
			man.OK++
		}
	}
	gotLogic := int64(0)
	for _, c := range order {
		if sz, ok := parseSize(plan[c].size); ok {
			gotLogic += sz
		}
	}
	man.Debs = len(order)
	man.LogicalSize = gotLogic

	arch := &archiver{
		f:         f,
		lg:        logger,
		cache:     newAssetCache(),
		eg:        &errGroup{seen: map[string]int{}},
		baseURL:   baseURL,
		repoDir:   repoDir,
		assetsDir: filepath.Join(repoDir, "_archive", "assets"),
	}
	arch.initRun()
	iconByPkg, iconsSaved := arch.icons(pkgEntries)
	depArchives, depCount, imgCount := arch.depictions(pkgEntries)
	man.Icons = iconsSaved
	man.Depictions = depCount
	logger.Printf("archive: %d icons, %d depictions, %d depiction data files, %d assets, %d images, %d fetch errors",
		iconsSaved, depCount, arch.jsonSaved, arch.cache.archived(), imgCount, arch.eg.count())
	arch.eg.flush(logger)

	pkgData := buildBrowser(pkgEntries, fileStates, iconByPkg, depArchives, baseURL)
	pkgData.Name = name
	pkgData.Upstream = repo.URL
	pkgData.Mirror = man.Mirror
	pkgData.Release = man.Release
	pkgData.Synced = man.LastAttempt
	pkgData.Unique = len(pkgData.Packages)
	man.Unique = len(pkgData.Packages)
	if err := writeBrowserArtifacts(dataDir, pkgData); err != nil {
		logger.Printf("browser artifacts: %v", err)
		man.Error = err.Error()
		finish(statusFailed)
		return man
	}

	for p, body := range extras {
		if c, ok := safeRel(fileRel(p)); ok {
			if err := writeAtomic(filepath.Join(repoDir, c), body); err != nil {
				logger.Printf("write extra %s: %v", p, err)
				man.Error = err.Error()
				finish(statusFailed)
				return man
			}
		}
	}
	// external-URL Filename support: the mirrored index copies get their
	// external Filename lines rewritten to canonical pool paths (only for
	// repos confirmed unsigned — both InRelease and Release.gpg 404'd, see
	// sigAbsent, AND the Release body itself is not inline-clearsigned,
	// which pgpSigned catches; a rewritten signed Release would be invalid).
	// Indexes untouched by the rewrite are stored verbatim, keeping the
	// upstream checksums in the Release valid; only edited indexes need
	// recomputed checksums (updated). Indexes the mirror cannot store
	// (undecodable, or — when the rewrite must change their bytes —
	// formats the stdlib cannot regenerate like xz/zstd/bz2/lzma) are
	// dropped from the checksum lists so APT never requests them, and the
	// same goes for indexes the rewrite must edit whose upstream bytes
	// failed checksum verification (never bless unverified data)
	rewrittenEnabled := len(canon) != 0 && sigAbsent["InRelease"] && sigAbsent["Release.gpg"] && !pgpSigned(relBody)
	// updated/dropped are keyed by the paths as the Release body lists
	// them (branch-relative: "main/binary-.../Packages"), NOT repo-root
	// relative — dists-style Release files list paths relative to their
	// own directory, so fileRel keys would never match a checksum line
	updated, dropped, mirrored := map[string][]byte{}, map[string]bool{}, map[string]bool{}
	for _, p := range sortedKeys(fetched) {
		c, ok := safeRel(fileRel(p))
		if !ok {
			continue
		}
		body := fetched[p]
		if rewrittenEnabled && isIndexPath(p) {
			out, okIdx, edited := mirrorIndexBody(p, body, canon)
			if !okIdx {
				dropped[p] = true
				continue // not mirrored: undecodable, or a format the rewrite pass cannot regenerate
			}
			if edited && !verified[p] {
				// the rewrite must change these bytes, but they never
				// verified against the Release checksums — storing them
				// (and recomputing the sums) would bless corrupt upstream
				// data that apt would otherwise fail-closed on. Drop them
				// from the checksum lists instead; verbatim storage of an
				// unverified-but-untouched index stays fine above
				dropped[p] = true
				continue
			}
			body = out
			if edited {
				updated[p] = out
			}
		}
		if err := writeAtomic(filepath.Join(repoDir, c), body); err != nil {
			logger.Printf("write index %s: %v", p, err)
			man.Error = err.Error()
			finish(statusFailed)
			return man
		}
		if isIndexPath(p) {
			mirrored[p] = true
		}
	}
	// indexes Release listed but the mirror does not store (fetch errors,
	// or formats the rewrite pass cannot regenerate) must leave the
	// checksum lists too, or APT would request a 404
	if rewrittenEnabled {
		for p := range ri.Entries {
			if !isIndexPath(p) {
				continue
			}
			if !mirrored[p] {
				dropped[p] = true
			}
		}
	}
	relFinal := relBody
	if rewrittenEnabled {
		relFinal = rewriteReleaseChecksums(relBody, updated, dropped)
		// a confirmed-unsigned repo may still have a stale signed file on
		// disk from an earlier sync (upstream since dropped signing); APT
		// prefers InRelease, so a leftover copy would override the
		// rewritten Release and fail verification against it
		for _, p := range []string{"InRelease", "Release.gpg"} {
			if c, ok := safeRel(fileRel(p)); ok {
				if err := os.Remove(filepath.Join(repoDir, c)); err != nil && !os.IsNotExist(err) {
					logger.Printf("remove stale %s: %v", p, err)
				}
			}
		}
	}
	if err := writeAtomic(filepath.Join(repoDir, filepath.FromSlash(fileRel("Release"))), relFinal); err != nil {
		logger.Printf("write Release: %v", err)
		man.Error = err.Error()
		finish(statusFailed)
		return man
	}

	man.Updated = formatTime(now)
	finish(statusSynced)
	logger.Printf("synced: %d packages / %d versions, %d debs ok / %d missing / %d locked, %s referenced",
		man.Unique, man.Versions, man.OK, len(man.Missing), len(man.Locked), humanSize(man.LogicalSize))
	return man
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func buildBrowser(entries []PkgEntry, fileStates map[string]debStatus, iconByPkg map[string]string, depArchives map[string]archivedDepiction, baseURL string) *BrowserData {
	groups := map[string]*BrowserPackage{}
	var ids []string
	for _, e := range entries {
		id := e.ID()
		if id == "" {
			continue
		}
		bp, ok := groups[id]
		if !ok {
			bp = &BrowserPackage{ID: id, Versions: []BrowserVersion{}}
			groups[id] = bp
			ids = append(ids, id)
		}
		if v := e.Get("name"); v != "" {
			bp.Name = v
		}
		if v := e.Get("section"); v != "" {
			bp.Section = v
		}
		if v := e.Get("homepage"); v != "" {
			if resolved, okH := resolveRef(baseURL, v); okH {
				bp.Homepage = resolved
			}
		}
		if bp.Description == "" {
			bp.Description = firstLine(e.Get("description"))
		}
		row := BrowserVersion{
			Version: e.Version(),
			Status:  statusOK,
			Size:    mustParseSize(e.Get("size")),
			Shasum:  e.Get("sha256"),
			Author:  e.Get("author"),
			Compat:  firstLine(e.Get("compatibility")),
		}
		if fn := e.Filename(); fn != "" {
			c, _, okS := canonicalDebPath(e)
			if !okS {
				row.Status, row.Reason = statusMissing, "invalid path"
			} else {
				row.Deb = c
				if s, okS2 := fileStates[c]; okS2 {
					row.Status = s.state
					row.Reason = s.reason
				}
			}
		} else {
			row.Status = statusMissing
			row.Reason = "no file listed"
		}
		refs := []DepictRef{}
		refSeen := map[string]bool{}
		for _, key := range []string{"depiction", "sileodepiction"} {
			raw := strings.TrimSpace(e.Get(key))
			if raw == "" {
				continue
			}
			res, okS := resolveRef(baseURL, raw)
			if !okS || refSeen[res] {
				continue
			}
			refSeen[res] = true
			ref := DepictRef{Original: res}
			if info := depArchives[res]; info.rel != "" {
				ref.Archived = info.rel
				ref.Static = info.static
			}
			refs = append(refs, ref)
		}
		row.Depictions = refs
		bp.Versions = append(bp.Versions, row)
	}
	sort.Strings(ids)
	out := make([]BrowserPackage, 0, len(ids))
	for _, id := range ids {
		bp := groups[id]
		bp.Icon = iconByPkg[id]
		out = append(out, *bp)
	}
	return &BrowserData{Packages: out}
}

func firstLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.Index(s, "\n"); i >= 0 {
		s = s[:i]
	}
	return s
}
