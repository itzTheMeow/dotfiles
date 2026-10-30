package main

import (
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const (
	statusOK      = "ok"
	statusMissing = "missing"
	statusLocked  = "locked"
	statusSynced  = "synced"
	statusFailed  = "failed"
	statusStale   = "stale"
)

func parseSize(s string) (int64, bool) {
	n, err := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	if err != nil || n < 0 {
		return 0, false
	}
	return n, true
}

func symlinkDepth(rel string) int {
	d := filepath.Dir(rel)
	if d == "." {
		return 0
	}
	return strings.Count(d, "/") + 1
}

func poolLinkTarget(depth int, key string) string {
	return strings.Repeat("../", depth+1) + "_pool/" + key + ".deb"
}

func makeSymlink(dest, target string) error {
	dir := filepath.Dir(dest)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if fi, err := os.Lstat(dest); err == nil {
		if fi.Mode()&os.ModeSymlink != 0 {
			if link, err2 := os.Readlink(dest); err2 == nil && link == target {
				return nil
			}
		}
		if err := os.Remove(dest); err != nil {
			return err
		}
	}
	return os.Symlink(target, dest)
}

func applyFetchError(st *debStatus, reqURL string, err error) {
	var notFound, locked bool
	if errors.Is(err, ErrNotFound) {
		notFound = true
	} else if errors.Is(err, ErrLocked) {
		locked = true
	}
	switch {
	case notFound:
		st.state, st.reason = statusMissing, "404"
	case locked:
		st.state, st.reason = statusLocked, "paid or auth-required"
	default:
		st.state, st.reason = statusMissing, strings.TrimSpace(strings.TrimPrefix(err.Error(), reqURL+": "))
	}
}

// pullVerifiedIntoPool moves a freshly-verified local copy into the shared
// pool and converts dest into a symlink pointing there. Returns true on
// success, false if the symlink could not be created.
func pullVerifiedIntoPool(dest, poolFile, key string, depth int) bool {
	if _, err := os.Stat(poolFile); err == nil {
		os.Remove(dest)
	} else if err := os.Rename(dest, poolFile); err != nil {
		return false
	}
	if err := makeSymlink(dest, poolLinkTarget(depth, key)); err != nil {
		log.Printf("pool symlink %s: %v", dest, err)
		return false
	}
	return true
}

// ensureDeb mirrors one referenced .deb: shared-pool storage when the index
// provides a checksum, plain local copy otherwise. st.state becomes
// "ok", "missing" (retry next run) or "locked" (paid package).
// deb paths are rooted at the repository root (APT resolves Filename against
// the sources-list base), even for dists-style repos.
func ensureDeb(f *Fetcher, baseURL, repoDir, poolPath string, st *debStatus) {
	t := st.task
	st.state, st.reason = statusMissing, ""
	if t.file == "" {
		return
	}
	dest := filepath.Join(repoDir, filepath.FromSlash(t.file))
	depth := symlinkDepth(t.file)
	key := poolKeyOf(t)
	poolFile := ""
	if key != "" {
		poolFile = filepath.Join(poolPath, key+".deb")
	}
	expectedLink := poolLinkTarget(depth, key)

	if key != "" {
		if fi, err := os.Stat(poolFile); err == nil {
			if sizeFits(fi.Size(), t.size) {
				if err := makeSymlink(dest, expectedLink); err == nil {
					st.state = statusOK
					return
				}
				log.Printf("pool %s: symlink failed, refetching: %v", key, err)
			} else {
				log.Printf("pool %s: cached size %d unexpected, refetching", key, fi.Size())
			}
		}
	}

	if fi, err := os.Lstat(dest); err == nil {
		if fi.Mode()&os.ModeSymlink != 0 {
			if link, err2 := os.Readlink(dest); err2 == nil && key != "" && link == expectedLink {
				// stat through the link: Lstat on the symlink itself only
				// yields the target string length
				if pf, errP := os.Stat(poolFile); errP == nil && sizeFits(pf.Size(), t.size) {
					st.state = statusOK
					return
				}
			}
			os.Remove(dest)
		} else if fi.Mode().IsRegular() && sizeFits(fi.Size(), t.size) {
			if err := verifyFileHash(dest, t.sha, t.md5); err == nil {
				if key == "" {
					st.state = statusOK
					return
				}
				if pullVerifiedIntoPool(dest, poolFile, key, depth) {
					st.state = statusOK
					return
				}
			}
			os.Remove(dest)
		} else {
			// unknown file type under the deb path: start over
			os.Remove(dest)
		}
	}

	reqURL := t.url
	if reqURL == "" {
		// deb paths are rooted at the repository root (APT resolves
		// Filename against the sources-list base), even for dists-style
		// repos; external-URL Filenames skip this join entirely
		reqURL = joinRawURL(baseURL, t.file)
	}
	if key != "" {
		if _, err := f.Download(reqURL, poolFile, t.size, t.sha, t.md5); err != nil {
			applyFetchError(st, reqURL, err)
			return
		}
		if err := makeSymlink(dest, expectedLink); err != nil {
			log.Printf("%s: symlink: %v", t.file, err)
			st.state, st.reason = statusMissing, err.Error()
			return
		}
		st.state = statusOK
		return
	}

	resp, err := f.do(http.MethodGet, reqURL, "", 2)
	if err != nil {
		applyFetchError(st, reqURL, err)
		return
	}
	defer resp.Body.Close()
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		st.reason = err.Error()
		return
	}
	fh, err := os.OpenFile(dest+".tmp", os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		st.reason = err.Error()
		return
	}
	n, readErr := io.Copy(fh, io.LimitReader(resp.Body, maxDebBytes+1))
	closeErr := fh.Close()
	if readErr != nil || closeErr != nil {
		os.Remove(dest + ".tmp")
		st.reason = fmt.Sprintf("download: %v", firstErr(readErr, closeErr))
		return
	}
	if n > maxDebBytes {
		os.Remove(dest + ".tmp")
		st.reason = fmt.Sprintf("download exceeds %d bytes", maxDebBytes)
		return
	}
	if !sizeFits(n, t.size) {
		os.Remove(dest + ".tmp")
		st.reason = fmt.Sprintf("size mismatch: got %d want %s", n, t.size)
		return
	}
	if err := os.Rename(dest+".tmp", dest); err != nil {
		os.Remove(dest + ".tmp")
		st.reason = err.Error()
		return
	}
	st.state = statusOK
}

func firstErr(errs ...error) error {
	for _, e := range errs {
		if e != nil {
			return e
		}
	}
	return nil
}
