package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
)

// depictCacheHarness serves one depiction page + its icon per id, counting
// depiction fetches
type depictCacheServer struct {
	srv   *httptest.Server
	fetch atomic.Int64
}

func newDepictCacheServer(t *testing.T) *depictCacheServer {
	t.Helper()
	s := &depictCacheServer{}
	mux := http.NewServeMux()
	mux.HandleFunc("/depiction/pkg/pkg.html", func(w http.ResponseWriter, r *http.Request) {
		s.fetch.Add(1)
		_, _ = io.WriteString(w, `<html><head><meta property="og:image" content="/icon/pkg.png"></head><body><h1>pkg depictions</h1></body></html>`)
	})
	mux.HandleFunc("/icon/pkg.png", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("png-bytes"))
	})
	s.srv = httptest.NewServer(mux)
	t.Cleanup(s.srv.Close)
	// the depictions walker treats its own host as same-host assets; the
	// og:image cross-host image fetch is the only other request
	return s
}

func (s *depictCacheServer) fetcher() *Fetcher {
	f := NewFetcher(false)
	return f
}

func cacheArchiver(t *testing.T, repoDir, baseURL string) *archiver {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(repoDir, "_archive", "depictions"), 0o755); err != nil {
		t.Fatal(err)
	}
	f := (&depictCacheServer{}).fetcher()
	// mirror syncOne: the repo's own (operator-configured) host is exempt
	// from initial-request internal-host screening; the httptest server is
	// a loopback host and would otherwise be blocked outright
	if u, errP := url.Parse(baseURL); errP == nil {
		f.allowHost(u.Host)
	}
	return &archiver{
		f:       f,
		lg:      log.New(io.Discard, "", 0),
		cache:   newAssetCache(),
		eg:      &errGroup{seen: map[string]int{}},
		baseURL: baseURL,
		repoDir: repoDir,
	}
}

func TestDeadGuardLockedMemo(t *testing.T) {
	// ErrLocked per-URL memoization must round-trip through the memo file
	repoDir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(repoDir, "_meta"), 0o755); err != nil {
		t.Fatal(err)
	}
	arch := cacheArchiver(t, repoDir, "https://x")
	g := arch.newDeadGuard("depictions")
	url := "https://paywall.example.com/depiction/pkg/pkg.html"
	g.fail(url, ErrLocked)
	// network-dead hosts must NOT be triggered by a locked response
	if g.hostGone("paywall.example.com") {
		t.Fatal("locked response pinned the host dead")
	}
	g.settle()

	arch2 := cacheArchiver(t, repoDir, "https://x")
	g2 := arch2.newDeadGuard("depictions")
	if !g2.skip(url) {
		t.Fatal("locked URL was not memoized across guards")
	}
	// the canary still holding (any error incl. ErrLocked) keeps others dead;
	// check the memo file itself
	raw, err := os.ReadFile(filepath.Join(repoDir, "_meta", "deadDepictions.json"))
	if err != nil || !bytes.Contains(raw, []byte(url)) {
		t.Fatalf("memo file missing url: %v %s", err, raw)
	}
}

func TestDepictionSkipCache(t *testing.T) {
	srv := newDepictCacheServer(t)
	base := srv.srv.URL
	repoDir := t.TempDir()
	a1 := cacheArchiver(t, repoDir, base)
	a1.initRun()
	entries := []PkgEntry{
		{Fields: map[string]string{"package": "pkg", "version": "1.0", "depiction": base + "/depiction/pkg/pkg.html"}},
	}

	// first run: fetched, cached
	arch1, n1, _ := a1.depictions(entries)
	if n1 != 1 || arch1[base+"/depiction/pkg/pkg.html"].rel == "" {
		t.Fatalf("first run did not archive: n=%d arch=%v", n1, arch1)
	}

	// second run at the same version: skip cache serves it, zero fetches
	a2 := cacheArchiver(t, repoDir, base)
	a2.initRun()
	arch2, n2, _ := a2.depictions(entries)
	if n2 != 1 {
		t.Fatalf("second run lost the archived record: n=%d", n2)
	}
	d2, d1 := arch2[base+"/depiction/pkg/pkg.html"], arch1[base+"/depiction/pkg/pkg.html"]
	if d2 != d1 {
		t.Fatalf("reused record diverges: %v vs %v", d2, d1)
	}
	if got := srv.fetch.Load(); got != 1 {
		t.Fatalf("second run re-fetched depiction %d times", got)
	}

	// version bump on the same URL: re-fetches
	entries[0].Fields["version"] = "1.1"
	a3 := cacheArchiver(t, repoDir, base)
	a3.initRun()
	if _, n3, _ := a3.depictions(entries); n3 != 1 {
		t.Fatal("bumped version not archived")
	}
	if got := srv.fetch.Load(); got != 2 {
		t.Fatalf("version bump did not re-fetch (fetches=%d)", got)
	}

	// missing sidecar defeats the cache too
	os.Remove(filepath.Join(repoDir, "_archive", "depictions", "pkg-"+
		sha256Hex([]byte(base + "/depiction/pkg/pkg.html"))[:8]+"-static.html"))
	a4 := cacheArchiver(t, repoDir, base)
	a4.initRun()
	if _, n4, _ := a4.depictions(entries); n4 != 1 {
		t.Fatal("missing sidecar not re-archived")
	}
	if got := srv.fetch.Load(); got != 3 {
		t.Fatalf("corrupted cache did not re-fetch (fetches=%d)", got)
	}
}

func TestDepictionSkipCacheVersionBump(t *testing.T) {
	// a stale file produced by an older depictionVersion must be ignored:
	// the cache path writes version=depictionVersion, so synthesize a file
	// claiming version 0 and confirm refetch (via artifacts not trusted)
	repoDir := t.TempDir()
	st := &depictState{Version: depictionVersion - 1, URLs: map[string]*depictVersed{
		"https://x/y.html": {Versions: []string{"9.9"}, Static: true},
	}}
	if err := os.MkdirAll(filepath.Join(repoDir, "_archive", "depictions"), 0o755); err != nil {
		t.Fatal(err)
	}
	// write via a manually-versioned state
	raw, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := writeAtomic(filepath.Join(repoDir, "_meta", "depictions.state"), raw); err != nil {
		t.Fatal(err)
	}
	a := cacheArchiver(t, repoDir, "https://x")
	if len(a.loadDepictState().URLs) != 0 {
		t.Fatal("stale-version state was not invalidated")
	}
}
