package main

import (
	"os"
	"path/filepath"
	"sync"
	"testing"
)

// TestWriteAtomicConcurrent guards against the deployed ENOENT flood:
// content-hash asset naming gives concurrent same-content writers the same
// dest, which used to mean one shared .tmp path — the losing rename made
// chmod/rename of the winner's tmp fail with "no such file or directory"
func TestWriteAtomicConcurrent(t *testing.T) {
	dir := t.TempDir()
	dest := filepath.Join(dir, "0123456789abcdef-article")
	payload := []byte("identical signed-out redirect body")
	var wg sync.WaitGroup
	errs := make(chan error, 16)
	for range 16 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := writeAtomic(dest, payload); err != nil {
				errs <- err
			}
		}()
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Fatalf("concurrent writeAtomic: %v", err)
	}
	got, err := os.ReadFile(dest)
	if err != nil || string(got) != string(payload) {
		t.Fatalf("final dest wrong: %v %q", err, got)
	}
	// no tmp litter left behind
	matches, _ := filepath.Glob(filepath.Join(dir, ".*.tmp"))
	if len(matches) != 0 {
		t.Fatalf("tmp litter left: %v", matches)
	}
}

// TestSweepTmps pins the litter-shape contract: dot-prefixed .tmp anywhere
// in the tree goes, dotless pool tmps and dot-but-not-tmp files stay
func TestSweepTmps(t *testing.T) {
	root := t.TempDir()
	litter := []string{
		filepath.Join(root, ".repos.json.a1b2c3d4e5.tmp"),                       // data-dir root
		filepath.Join(root, "_search", ".pkgsx.json.f00fb00b00.tmp"),            // shards
		filepath.Join(root, "pluvictest", "_meta", ".manifest.json.abc123.tmp"), // manifest dir
		filepath.Join(root, "pluvictest", "_archive", "depictions", ".x.9876543210ef.tmp"),
	}
	keep := []string{
		filepath.Join(root, ".hidden"),                        // dot but not tmp
		filepath.Join(root, "pluvictest", "Packages.gz"),      // legit mirrored content
		filepath.Join(root, "_pool", "main-deb.7ffef00f.tmp"), // pool shape: no dot, pool loop owns it
	}
	for _, p := range append(litter, keep...) {
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	sweepTmps(root)
	for i, p := range litter {
		if _, err := os.Lstat(p); err == nil {
			t.Errorf("sweepTmps: litter %d should be removed: %s", i, p)
		}
	}
	for i, p := range keep {
		if _, err := os.Lstat(p); err != nil {
			t.Errorf("sweepTmps: kept file %d should survive: %s: %v", i, p, err)
		}
	}
}
