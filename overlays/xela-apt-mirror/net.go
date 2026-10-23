package main

import (
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

var (
	ErrNotFound = errors.New("http 404")
	ErrLocked   = errors.New("http 4xx locked")
)

type Fetcher struct {
	client *http.Client
	ua     string
}

func NewFetcher(insecure bool) *Fetcher {
	t := http.DefaultTransport.(*http.Transport).Clone()
	if insecure {
		cfg := t.TLSClientConfig
		if cfg == nil {
			cfg = new(tls.Config)
		}
		clone := cfg.Clone()
		clone.InsecureSkipVerify = true
		t.TLSClientConfig = clone
	}
	return &Fetcher{
		client: &http.Client{
			Transport: t,
			Timeout:   120 * time.Second,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if len(via) >= 10 {
					return fmt.Errorf("too many redirects")
				}
				if req.URL.Scheme != "http" && req.URL.Scheme != "https" {
					return fmt.Errorf("redirect to non-http scheme %q", req.URL.Scheme)
				}
				if isInternalHost(req.URL.Host) {
					return fmt.Errorf("redirect to internal host %q", req.URL.Host)
				}
				return nil
			},
		},
		ua: "xela-apt-mirror/1.0",
	}
}

func (f *Fetcher) do(method, rawurl, accept string, retries int) (*http.Response, error) {
	var lastErr error
	for attempt := 0; attempt <= retries; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * 3 * time.Second)
		}
		req, err := http.NewRequest(method, rawurl, nil)
		if err != nil {
			return nil, fmt.Errorf("build request: %w", err)
		}
		req.Header.Set("User-Agent", f.ua)
		if accept != "" {
			req.Header.Set("Accept", accept)
		}
		resp, err := f.client.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("%s: %w", rawurl, err)
			continue
		}
		switch resp.StatusCode {
		case http.StatusOK:
			return resp, nil
		case http.StatusNotFound, http.StatusGone:
			resp.Body.Close()
			return nil, fmt.Errorf("%s: %w", rawurl, ErrNotFound)
		case http.StatusUnauthorized, http.StatusForbidden, http.StatusPaymentRequired:
			resp.Body.Close()
			return nil, fmt.Errorf("%s: %w", rawurl, ErrLocked)
		case http.StatusTooManyRequests, http.StatusServiceUnavailable:
			resp.Body.Close()
			lastErr = fmt.Errorf("%s: %s", rawurl, resp.Status)
			continue
		default:
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
			resp.Body.Close()
			return nil, fmt.Errorf("%s: %s: %s", rawurl, resp.Status, body)
		}
	}
	return nil, lastErr
}

func (f *Fetcher) Fetch(rawurl string) ([]byte, string, error) {
	resp, err := f.do(http.MethodGet, rawurl, "", 2)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxFetchBytes+1))
	if err != nil {
		return nil, "", fmt.Errorf("read %s: %w", rawurl, err)
	}
	if int64(len(body)) > maxFetchBytes {
		return nil, "", fmt.Errorf("read %s: response exceeds %d bytes", rawurl, maxFetchBytes)
	}
	return body, resp.Header.Get("Content-Type"), nil
}

func (f *Fetcher) Download(rawurl, dest, size, sha256Hex, md5Hex string) (int64, error) {
	resp, err := f.do(http.MethodGet, rawurl, "", 2)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if size != "" {
		want, _ := strconv.ParseInt(size, 10, 64)
		if want > 0 && resp.ContentLength > 0 && resp.ContentLength != want {
			return 0, fmt.Errorf("%s: content-length %d != expected %s", rawurl, resp.ContentLength, size)
		}
	}
	dir := filepath.Dir(dest)
	fh, err := os.CreateTemp(dir, filepath.Base(dest)+".*.tmp")
	if err != nil {
		return 0, fmt.Errorf("open tmp: %w", err)
	}
	tmp := fh.Name()
	n, readErr := io.Copy(fh, io.LimitReader(resp.Body, maxDebBytes+1))
	closeErr := fh.Close()
	if err2 := os.Chmod(tmp, 0o644); err2 != nil && closeErr == nil {
		closeErr = err2
	}
	if readErr != nil {
		os.Remove(tmp)
		return 0, fmt.Errorf("download body: %w", readErr)
	}
	if n > maxDebBytes {
		os.Remove(tmp)
		return 0, fmt.Errorf("%s: download exceeds %d bytes", rawurl, maxDebBytes)
	}
	if closeErr != nil {
		os.Remove(tmp)
		return 0, closeErr
	}
	if size != "" {
		want, _ := strconv.ParseInt(size, 10, 64)
		if want > 0 && n != want {
			os.Remove(tmp)
			return 0, fmt.Errorf("%s: got %d bytes, expected %s", rawurl, n, size)
		}
	}
	if err := verifyFileHash(tmp, sha256Hex, md5Hex); err != nil {
		os.Remove(tmp)
		return n, err
	}
	if err := os.Rename(tmp, dest); err != nil {
		os.Remove(tmp)
		return n, fmt.Errorf("rename: %w", err)
	}
	return n, nil
}

func writeAtomic(dest string, data []byte) error {
	dir := filepath.Dir(dest)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	tmp := filepath.Join(dir, "."+filepath.Base(dest)+".tmp")
	fh, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	if _, err := fh.Write(data); err != nil {
		fh.Close()
		os.Remove(tmp)
		return err
	}
	if err := fh.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	if err := os.Chmod(tmp, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, dest)
}
