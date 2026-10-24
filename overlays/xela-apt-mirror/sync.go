package main

import (
	"encoding/json"
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
	Reason string `json:"reason"`
	Size   string `json:"size,omitempty"`
	Sha    string `json:"sha,omitempty"`
	Md5    string `json:"md5,omitempty"`
}

type RepoManifest struct {
	Name         string            `json:"name"`
	URL          string            `json:"url"`
	Distribution string            `json:"distribution,omitempty"`
	Mirror       string            `json:"mirror"`
	Status       string            `json:"status"`
	Error        string            `json:"error,omitempty"`
	Updated      string            `json:"updated"`
	LastAttempt  string            `json:"attempted"`
	Release      map[string]string `json:"release,omitempty"`
	Indexes      []string          `json:"indexes,omitempty"`
	Unique       int               `json:"uniquePackages"`
	Versions     int               `json:"packageVersions"`
	Debs         int               `json:"debs"`
	LogicalSize  int64             `json:"logicalBytes"`
	OK           int               `json:"debsOk"`
	Missing      []MissingDeb      `json:"missing,omitempty"`
	Locked       []MissingDeb      `json:"locked,omitempty"`
	Icons        int               `json:"icons"`
	Depictions   int               `json:"depictions"`
}

type DepictRef struct {
	Original string `json:"original"`
	Archived string `json:"archived,omitempty"`
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

func fetchOptional(f *Fetcher, rawurl string) ([]byte, error) {
	body, _, err := f.Fetch(rawurl)
	if err != nil {
		return nil, err
	}
	return body, nil
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

func poolDir(dataDir string) string { return filepath.Join(dataDir, "_pool") }

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
	for _, p := range []string{"InRelease", "Release.gpg", "Release.key", "CydiaIcon.png", "CydiaIcon.svg"} {
		if body, err := fetchOptional(f, joinRawURL(branchBase, p)); err == nil {
			extras[p] = body
		}
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
	for _, e := range pkgEntries {
		fn := e.Filename()
		if fn == "" {
			continue
		}
		c, ok := safeRel(fn)
		if !ok {
			logger.Printf("unsafe filename %q skipped", fn)
			continue
		}
		if _, dup := plan[c]; dup {
			continue
		}
		plan[c] = debTask{file: c, size: e.Get("size"), sha: e.Get("sha256"), md5: e.Get("md5sum")}
		order = append(order, c)
	}
	if old != nil {
		present := map[string]bool{}
		for _, c := range order {
			present[c] = true
		}
		retry := func(list []MissingDeb) {
			for _, md := range list {
				if !present[md.File] {
					present[md.File] = true
					if _, ok := safeRel(md.File); ok {
						plan[md.File] = debTask{file: md.File, size: md.Size, sha: md.Sha, md5: md.Md5}
						order = append(order, md.File)
					}
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
			man.Missing = append(man.Missing, MissingDeb{File: s.task.file, Reason: s.reason, Size: s.task.size, Sha: s.task.sha, Md5: s.task.md5})
		case statusLocked:
			man.Locked = append(man.Locked, MissingDeb{File: s.task.file, Reason: s.reason, Size: s.task.size, Sha: s.task.sha, Md5: s.task.md5})
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
	arch.initJSON()
	iconByPkg, iconsSaved := arch.icons(pkgEntries)
	depArchived, depCount := arch.depictions(pkgEntries)
	man.Icons = iconsSaved
	man.Depictions = depCount
	logger.Printf("archive: %d icons, %d depictions, %d depiction data files, %d assets, %d fetch errors",
		iconsSaved, depCount, arch.jsonSaved, arch.cache.archived(), arch.eg.count())
	arch.eg.flush(logger)

	pkgData := buildBrowser(pkgEntries, fileStates, iconByPkg, depArchived, baseURL)
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
	for _, p := range sortedKeys(fetched) {
		if c, ok := safeRel(fileRel(p)); ok {
			if err := writeAtomic(filepath.Join(repoDir, c), fetched[p]); err != nil {
				logger.Printf("write index %s: %v", p, err)
				man.Error = err.Error()
				finish(statusFailed)
				return man
			}
		}
	}
	if err := writeAtomic(filepath.Join(repoDir, filepath.FromSlash(fileRel("Release"))), relBody); err != nil {
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

func buildBrowser(entries []PkgEntry, fileStates map[string]debStatus, iconByPkg map[string]string, depArchived map[string]string, baseURL string) *BrowserData {
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
			c, okS := safeRel(fn)
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
			if rel := depArchived[res]; rel != "" {
				ref.Archived = rel
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
