package main

// Sweep reclaims disk for repos that left the config: their data dirs and
// their now-orphaned _pool entries. Runs single-threaded in main after
// every syncOne has finished (so last-known-good symlinks reflect the
// current indexes) and after generateLanding (so search shards and
// repos.json are consistent first).
//
// The keep-set is the union of pool keys referenced by the symlinks of
// every REMAINING repo, so a deb shared by several repos stays in the
// pool until the last referencing repo is gone. Entries dropped from a
// repo's own current indexes but still symlinked survive (they can be
// re-linked from the manifest retry lists next sync); true orphans go.

import (
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"strings"
)

var sweepReserved = []string{"_pool", "_search", "assets", "repos.json", "index.html"}

// poolKeysOfRepo walks one repo's dir collecting _pool keys referenced by
// its symlinks; _archive/_meta are skipped (they hold no deb paths)
func poolKeysOfRepo(repoDir string, dst map[string]bool) {
	_ = filepath.WalkDir(repoDir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // unreadable subtree: leave its poolEntries alone
		}
		if d.IsDir() {
			switch d.Name() {
			case "_archive", "_meta":
				return filepath.SkipDir
			}
			return nil
		}
		if d.Type()&fs.ModeSymlink == 0 {
			return nil
		}
		linkB, err := os.Readlink(p)
		if err != nil {
			return nil
		}
		if parent := filepath.Base(filepath.Dir(linkB)); parent != "_pool" {
			return nil
		}
		if key, ok := poolKeyFromName(filepath.Base(linkB)); ok {
			dst[key] = true
		}
		return nil
	})
}

// poolKeyFromName strips a pool filename to a keep-set key; both the
// symlink targets and the pool files go through this so both sides agree
func poolKeyFromName(base string) (string, bool) {
	name := strings.TrimSuffix(base, ".deb")
	if name == "" || name == base {
		return "", false
	}
	if strings.HasPrefix(name, "md5-") {
		name = name[4:]
	}
	return name, isHexKey(name)
}

func isHexKey(s string) bool {
	for _, c := range s {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return len(s) >= 16 // sha256/md5 are long; stray non-hashes never reach the pool
}

// sweep removes dirs of repos absent from the config and unreferenced
// _pool files; config lists which repos are meant to exist
func sweep(cfg *Config) {
	keep := map[string]bool{}
	for _, r := range cfg.Repos {
		poolKeysOfRepo(filepath.Join(cfg.DataDir, r.Name), keep)
	}

	// repo dirs that are gone from the config: delete outright
	entries, err := os.ReadDir(cfg.DataDir)
	if err != nil {
		log.Printf("sweep data dir: %v", err)
		return
	}
	for _, e := range entries {
		name := e.Name()
		if containsName(sweepReserved, name) {
			continue
		}
		if !e.IsDir() {
			continue
		}
		if hasRepoName(cfg, name) {
			continue
		}
		dirFi, diErr := e.Info()
		if diErr != nil {
			dirFi = nil
		}
		size, n := dirSize(dirFi, filepath.Join(cfg.DataDir, name))
		if err := os.RemoveAll(filepath.Join(cfg.DataDir, name)); err != nil {
			log.Printf("sweep: remove old repo %s: %v", name, err)
			continue
		}
		log.Printf("sweep: removed repo dir %s (%d files, %s)", name, n, humanSize(size))
	}

	// pool: drop anything no remaining repo symlinks to
	poolDir := poolDir(cfg.DataDir)
	poolEntries, err := os.ReadDir(poolDir)
	if err != nil && !os.IsNotExist(err) {
		log.Printf("sweep pool: %v", err)
		return
	}
	freed, n := int64(0), 0
	for _, e := range poolEntries {
		name := e.Name()
		if e.IsDir() {
			continue
		}
		// pool tmp files come from os.CreateTemp-based downloads that
		// crashed before their rename; sweepable unconditionally
		if strings.HasSuffix(name, ".tmp") {
			if err := os.Remove(filepath.Join(poolDir, name)); err == nil {
				n++
			}
			continue
		}
		if !strings.HasSuffix(name, ".deb") {
			continue
		}
		key, ok := poolKeyFromName(name)
		if !ok {
			continue
		}
		if keep[key] {
			continue
		}
		fi, fiErr := e.Info()
		if fiErr != nil {
			fi = nil // fall through: stale entry is still sweepable
		}
		if err := os.Remove(filepath.Join(poolDir, e.Name())); err != nil {
			log.Printf("sweep: remove pool %s: %v", e.Name(), err)
			continue
		}
		n++
		if fi != nil {
			freed += fi.Size()
		}
	}
	if n != 0 {
		log.Printf("sweep: removed %d unreferenced pool files (%s)", n, humanSize(freed))
	}
}

func hasRepoName(cfg *Config, name string) bool {
	for _, r := range cfg.Repos {
		if r.Name == name {
			return true
		}
	}
	return false
}

func containsName(list []string, name string) bool {
	for _, v := range list {
		if v == name {
			return true
		}
	}
	return false
}

// dirSize walks a doomed repo dir for its count and byte total, for the
// log line only (pooled data inside it is symlinked and stays)
func dirSize(fi fs.FileInfo, root string) (int64, int) {
	if fi == nil {
		return 0, 0
	}
	var total int64
	var count int
	if fi.Mode().IsRegular() {
		return fi.Size(), 1
	}
	_ = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return filepath.SkipDir
		}
		if d.IsDir() {
			return nil
		}
		count++
		if info, err := d.Info(); err == nil {
			total += info.Size()
		}
		return nil
	})
	return total, count
}
