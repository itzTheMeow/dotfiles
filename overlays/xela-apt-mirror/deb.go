package main

import (
	"crypto/md5"
	"crypto/sha256"
	"errors"
	"fmt"
	"hash"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func parseSize(s string) int64 {
	n, err := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	if err != nil || n < 0 {
		return 0
	}
	return n
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
		st.state, st.reason = "missing", "404"
	case locked:
		st.state, st.reason = "locked", "paid or auth-required"
	default:
		st.state, st.reason = "missing", strings.TrimSpace(strings.TrimPrefix(err.Error(), reqURL))
	}
}

// pullVerifiedIntoPool moves a freshly-verified local copy into the shared
// pool and converts dest into a symlink pointing there
func pullVerifiedIntoPool(dest, poolFile, key string, depth int) {
	if _, err := os.Stat(poolFile); err == nil {
		_ = os.Remove(dest)
	} else if err := os.Rename(dest, poolFile); err != nil {
		return
	}
	if err := makeSymlink(dest, poolLinkTarget(depth, key)); err != nil {
		log.Printf("pool symlink %s: %v", dest, err)
	}
}

// ensureDeb mirrors one referenced .deb: shared-pool storage when the index
// provides a checksum, plain local copy otherwise. st.state becomes
// "ok", "missing" (retry next run) or "locked" (paid package).
func ensureDeb(f *Fetcher, baseURL, repoDir, poolPath string, st *debStatus) {
	t := st.task
	st.state, st.reason = "missing", ""
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

	if key != "" {
		if fi, err := os.Stat(poolFile); err == nil {
			if sizeFits(fi.Size(), t.size) {
				if err := makeSymlink(dest, poolLinkTarget(depth, key)); err == nil {
					st.state = "ok"
					return
				}
			} else {
				log.Printf("pool %s: cached size %d unexpected, refetching", key, fi.Size())
			}
		}
	}

	if fi, err := os.Lstat(dest); err == nil {
		if fi.Mode()&os.ModeSymlink != 0 {
			if link, err2 := os.Readlink(dest); err2 == nil && key != "" && strings.HasSuffix(link, "/_pool/"+key+".deb") {
				if sizeFits(fi.Size(), t.size) {
					st.state = "ok"
					return
				}
			}
			_ = os.Remove(dest)
		} else if fi.Mode().IsRegular() && sizeFits(fi.Size(), t.size) {
			if err := verifyFileHash(dest, t.sha, t.md5); err == nil {
				if key == "" {
					st.state = "ok"
					return
				}
				pullVerifiedIntoPool(dest, poolFile, key, depth)
				st.state = "ok"
				return
			}
			_ = os.Remove(dest)
		}
	}

	reqURL := joinRawURL(baseURL, t.file)
	if key != "" {
		if _, err := f.Download(reqURL, poolFile, t.size, t.sha, t.md5); err != nil {
			applyFetchError(st, reqURL, err)
			return
		}
		if err := makeSymlink(dest, poolLinkTarget(depth, key)); err != nil {
			log.Printf("%s: symlink: %v", t.file, err)
		}
		st.state = "ok"
		return
	}

	resp, err := f.do(http.MethodGet, reqURL, "", 2)
	if err != nil {
		applyFetchError(st, reqURL, err)
		return
	}
	defer resp.Body.Close()
	fh, err := os.OpenFile(dest+".tmp", os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		st.reason = err.Error()
		return
	}
	shaH, md5H := hash.Hash(sha256.New()), hash.Hash(md5.New())
	n, readErr := io.Copy(io.MultiWriter(fh, shaH, md5H), resp.Body)
	closeErr := fh.Close()
	if readErr != nil || closeErr != nil {
		_ = os.Remove(dest + ".tmp")
		_ = resp.Body.Close()
		st.reason = fmt.Sprintf("download: %v", firstErr(readErr, closeErr))
		return
	}
	_ = resp.Body.Close()
	if !sizeFits(n, t.size) {
		_ = os.Remove(dest + ".tmp")
		st.reason = fmt.Sprintf("size mismatch: got %d want %s", n, t.size)
		return
	}
	if err := os.Rename(dest+".tmp", dest); err != nil {
		_ = os.Remove(dest + ".tmp")
		st.reason = err.Error()
		return
	}
	st.state = "ok"
}

func firstErr(errs ...error) error {
	for _, e := range errs {
		if e != nil {
			return e
		}
	}
	return nil
}
