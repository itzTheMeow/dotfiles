package main

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func TestExternalFilenameURL(t *testing.T) {
	for raw, want := range map[string]bool{
		"https://github.com/j/releases/x.deb":         true,
		"http://github.com/x":                         true,
		"pool/main/k.deb":                             false,
		"./main/pool/k.deb":                           false,
		"https:/collapsed.example.com/k.deb":          false, // single slash: no host
		"ftp://host/k.deb":                            false,
		"/etc/passwd/":                                false,
		"https://user:pass@github.com/j/x.deb":        true,
		"https://github.com/j/releases/sp%20ace.deb":  true, // escaped space is fine
		"https://github.com/j/releases/bad space.deb": false,
	} {
		if _, ok := externalFilenameURL(raw); ok != want {
			t.Errorf("externalFilenameURL(%q) = %v", raw, ok)
		}
	}
}

func TestExternalDebPath(t *testing.T) {
	const sha = "b92e9f3b02f9ef1b81e4f5b6a44f7af1e0d6c7bd858353cc8f0de4fb7d0a3eb2"
	tk := debTask{url: "https://github.com/j/x.deb", sha: sha}
	if got := externalDebPath(tk); got != "pool/external/"+sha+".deb" {
		t.Fatalf("checksum key path wrong: %q", got)
	}
	// no checksum: stable URL digest, deterministic
	tk2 := debTask{url: "https://github.com/j/x.deb"}
	got := externalDebPath(tk2)
	if !regexp.MustCompile(`^pool/external/url-[0-9a-f]{12}\.deb$`).MatchString(got) {
		t.Fatalf("digest fallback wrong: %q", got)
	}
	if externalDebPath(tk2) != got {
		t.Fatal("digest path not deterministic")
	}
}

func TestRewriteExternalFilenames(t *testing.T) {
	body := []byte("Package: a\r\n" +
		"Filename: https://github.com/j/x.deb\r\n" +
		"Size: 100\r\n" +
		"Package: b\r\n" +
		"Filename: pool/main/b.deb\r\n")
	canon := map[string]string{"https://github.com/j/x.deb": "pool/external/abc.deb"}
	got := string(rewriteExternalFilenames(body, canon))
	want := "Package: a\nFilename: pool/external/abc.deb\nSize: 100\nPackage: b\nFilename: pool/main/b.deb\n"
	if got != want {
		t.Fatalf("rewrite mismatch:\n%q", got)
	}
	// empty canon: untouched, byte-faithful
	if string(rewriteExternalFilenames(body, nil)) != string(body) {
		t.Fatal("empty canon modified body")
	}
}

func TestIndexReencode(t *testing.T) {
	plain := []byte("Package: a\n")
	if got, ok := indexReencode("Packages", plain); !ok || !bytes.Equal(got, plain) {
		t.Fatal("plain passthrough failed")
	}
	enc, ok := indexReencode("Packages.gz", plain)
	if !ok {
		t.Fatal("gz not re-encodable")
	}
	zr, err := gzip.NewReader(bytes.NewReader(enc))
	if err != nil {
		t.Fatal(err)
	}
	back, _ := io.ReadAll(zr)
	if !bytes.Equal(back, plain) {
		t.Fatal("gz roundtrip mismatch")
	}
	for _, v := range []string{"Packages.xz", "Packages.bz2", "Packages.zst", "Packages.lzma"} {
		if _, ok := indexReencode(v, plain); ok {
			t.Fatalf("%s claims encodable", v)
		}
	}
}

func releaseFixture() []byte {
	return []byte(`Architectures: arm64
Components: main
MD5Sum:
 11111111111111111111111111111111 1111 Packages
 22222222222222222222222222222222 2222 Packages.gz
SHA256:
 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 200 Packages
 cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc 300 Packages.xz
SHA512:
 dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd 400 Packages
`)
}

func TestRewriteReleaseChecksums(t *testing.T) {
	plainBody, gzBody := []byte("new-plain"), []byte("new-gz")
	upd := map[string][]byte{"Packages": plainBody, "Packages.gz": gzBody}
	dropped := map[string]bool{"Packages.xz": true}
	got := string(rewriteReleaseChecksums(releaseFixture(), upd, dropped))
	want :=
		// header untouched
		"Architectures: arm64\nComponents: main\n" +
			// MD5Sum: both listed files rewritten with new digests+sizes
			"MD5Sum:\n" +
			" " + checksumHex("md5sum", plainBody) + " 9 Packages\n" +
			" " + checksumHex("md5sum", gzBody) + " 6 Packages.gz\n" +
			// SHA256: Packages rewritten, dropped Packages.xz line removed
			"SHA256:\n" +
			" " + checksumHex("sha256", plainBody) + " 9 Packages\n" +
			// SHA512: Packages rewritten
			"SHA512:\n" +
			" " + checksumHex("sha512", plainBody) + " 9 Packages\n"
	if got != want {
		t.Fatalf("release rewrite mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
	// unrelated Release (no updates, no drops) passes through untouched
	if string(rewriteReleaseChecksums(releaseFixture(), nil, nil)) != string(releaseFixture()) {
		t.Fatal("empty update modified unrelated release")
	}
}

func TestRewriteReleaseChecksumsSectionNames(t *testing.T) {
	newBody := []byte("new-body")
	upd := map[string][]byte{"Packages": newBody}
	// Checksums-Sha256 naming (Debian-style) must be rewritten with the
	// right digest, like the legacy SHA256: spelling
	body := []byte(`MD5Sum:
 11111111111111111111111111111111 1111 Packages
Checksums-Sha256:
 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 2222 ./Packages
`)
	got := string(rewriteReleaseChecksums(body, upd, nil))
	want := "MD5Sum:\n " + checksumHex("md5sum", newBody) + " 8 Packages\n" +
		"Checksums-Sha256:\n " + checksumHex("sha256", newBody) + " 8 ./Packages\n"
	if got != want {
		t.Fatalf("Checksums-Sha256 section mishandled:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
	// entries under an unrecognized section must not inherit the previous
	// section's algorithm — but the MD5Sum entry itself is still rewritten
	body2 := []byte(`MD5Sum:
 11111111111111111111111111111111 1111 Packages
Unknown-Field:
 33333333333333333333333333333333 2222 Packages
`)
	got2 := string(rewriteReleaseChecksums(body2, upd, nil))
	want2 := "MD5Sum:\n " + checksumHex("md5sum", newBody) + " 8 Packages\n" +
		"Unknown-Field:\n 33333333333333333333333333333333 2222 Packages\n"
	if got2 != want2 {
		t.Fatalf("unknown section algo leak:\n--- got ---\n%s\n--- want ---\n%s", got2, want2)
	}
	// trailing whitespace after the colon ("SHA256: ") must not hide the
	// section: parseRelease keys on line[:colon+1] and already recognizes
	// it, so a stale digest under such header would break apt verification
	body3 := []byte("MD5Sum:\n" +
		" 11111111111111111111111111111111 1111 Packages\n" +
		"SHA256: \n" +
		" bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 200 Packages.xz\n")
	upd3 := map[string][]byte{"Packages.xz": newBody}
	got3 := string(rewriteReleaseChecksums(body3, upd3, nil))
	want3 := "MD5Sum:\n" +
		" 11111111111111111111111111111111 1111 Packages\n" +
		"SHA256: \n" +
		" " + checksumHex("sha256", newBody) + " 8 Packages.xz\n"
	if got3 != want3 {
		t.Fatalf("trailing-space header mishandled:\n--- got ---\n%s\n--- want ---\n%s", got3, want3)
	}
}

func TestRewriteReleaseChecksumsTabIndent(t *testing.T) {
	newBody := []byte("new-body")
	upd := map[string][]byte{"Packages": newBody}
	// tab-indented entries are continuation lines just like space-indented
	// ones (parseRelease accepts both), so a tab-formatted Release must be
	// rewritten too — stale digests here would break apt verification
	body := []byte("MD5Sum:\n\t11111111111111111111111111111111 1111 Packages\n")
	got := string(rewriteReleaseChecksums(body, upd, nil))
	want := "MD5Sum:\n\t" + checksumHex("md5sum", newBody) + " 8 Packages\n"
	if got != want {
		t.Fatalf("tab-indented entry not rewritten:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}

func gzipOf(t *testing.T, body []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	if _, err := zw.Write(body); err != nil {
		t.Fatal(err)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func TestMirrorIndexBody(t *testing.T) {
	canon := map[string]string{"https://github.com/j/x.deb": "pool/external/abc.deb"}
	plainBody := []byte("Package: a\nFilename: pool/main/a.deb\n")
	extBody := []byte("Package: a\nFilename: https://github.com/j/x.deb\n")

	// untouched index (no external Filenames): upstream bytes verbatim,
	// not checksum-blessed — even in gz form, so no recompression happens
	upstreamGz := gzipOf(t, plainBody)
	out, stash, edited := mirrorIndexBody("dists/stable/main/binary-iphoneos-arm/Packages.gz", upstreamGz, canon)
	if !stash || edited || !bytes.Equal(out, upstreamGz) {
		t.Fatalf("untouched gzindex altered: stash=%v edited=%v verbatim=%v", stash, edited, bytes.Equal(out, upstreamGz))
	}
	out, stash, _ = mirrorIndexBody("Packages", plainBody, canon)
	if !stash || !bytes.Equal(out, plainBody) {
		t.Fatalf("untouched plain index altered: stash=%v verbatim=%v", stash, bytes.Equal(out, plainBody))
	}

	// external Filename: rewritten and re-encoded (regzipped), edited=true
	out, stash, edited = mirrorIndexBody("Packages.gz", gzipOf(t, extBody), canon)
	if !stash || !edited {
		t.Fatalf("external-Filename gz not rewritten: stash=%v edited=%v", stash, edited)
	}
	zr, err := gzip.NewReader(bytes.NewReader(out))
	if err != nil {
		t.Fatal(err)
	}
	back, _ := io.ReadAll(zr)
	if string(back) != "Package: a\nFilename: pool/external/abc.deb\n" {
		t.Fatalf("gz rewrite content mismatch: %q", back)
	}

	// plain path carries the rewritten plaintext directly
	out, stash, edited = mirrorIndexBody("Packages", extBody, canon)
	if !stash || !edited || string(out) != "Package: a\nFilename: pool/external/abc.deb\n" {
		t.Fatalf("plain rewrite mismatch: stash=%v edited=%v out=%q", stash, edited, out)
	}

	// undecodable (xz magic): never stored
	xzRaw := append([]byte{0xfd, '3', '7', 'z'}, bytes.Repeat([]byte{0xff}, 16)...)
	if _, stash, _ := mirrorIndexBody("Packages.xz", xzRaw, canon); stash {
		t.Fatal("xz-backed index stored")
	}

	// decodable but stdlib-irregenerable (bz2) WITH external Filenames: not stored
	bzExt, err := os.ReadFile(filepath.Join("testdata", "external-packages.bz2"))
	if err != nil {
		t.Fatal(err)
	}
	if out, stash, edited := mirrorIndexBody("Packages.bz2", bzExt, canon); stash || out != nil || edited {
		t.Fatalf("bz2 with external Filename stored: stash=%v edited=%v", stash, edited)
	}
	// ... but stored verbatim when it has no external Filenames
	bzPlain, err := os.ReadFile(filepath.Join("testdata", "plain-packages.bz2"))
	if err != nil {
		t.Fatal(err)
	}
	out, stash, edited = mirrorIndexBody("Packages.bz2", bzPlain, canon)
	if !stash || edited || !bytes.Equal(out, bzPlain) {
		t.Fatalf("untouched bz2 not stored verbatim: stash=%v edited=%v verbatim=%v", stash, edited, bytes.Equal(out, bzPlain))
	}
}

func TestRetryTaskValidation(t *testing.T) {
	unsafe := []string{"", ".", "..", "../evil.deb", "/abs/path.deb", "_meta/x.deb", "_pool/x.deb", "_archive/x.deb"}
	for _, p := range unsafe {
		if task, ok := retryTask(MissingDeb{File: p}); ok {
			t.Errorf("retryTask accepted unsafe file %q -> %q", p, task.file)
		}
	}
	for _, p := range []string{"pool/main/x.deb", "pool/external/abc.deb", "Packages"} {
		task, ok := retryTask(MissingDeb{File: p, Sha: "abc"})
		if !ok || task.file != p || task.sha != "abc" {
			t.Errorf("retryTask rejected safe file %q (task %+v ok %v)", p, task, ok)
		}
	}
	// external record: URL restores the direct download
	task, ok := retryTask(MissingDeb{File: "pool/external/abc.deb", URL: "https://github.com/j/x.deb", Sha: "abc"})
	if !ok || task.url != "https://github.com/j/x.deb" {
		t.Fatalf("external retry lost URL: task %+v ok %v", task, ok)
	}
	// malformed URL field: rejected rather than retried as a plain path
	if _, ok := retryTask(MissingDeb{File: "pool/external/abc.deb", URL: "not a url"}); ok {
		t.Fatal("retryTask accepted malformed URL")
	}
}

func TestFetcherInternalHostScreening(t *testing.T) {
	f := NewFetcher(false)
	// bracketed IPv6 literals without a port, trailing-dot spellings, and
	// mapped/unspecified literals previously slipped past the literal-IP
	// checks — the screening must normalize hosts to dialable form first
	for _, raw := range []string{
		"http://127.0.0.1/x", "http://localhost/x", "http://10.0.0.5/x",
		"http://192.168.1.1:8080/x", "http://[::1]/x", "http://[::1]:8080/x",
		"http://[::ffff:10.0.0.1]/x", "http://10.0.0.5./x", "http://0.0.0.0/x",
	} {
		if _, _, err := f.Fetch(raw); err == nil {
			t.Errorf("Fetch(%q) did not fail", raw)
		}
	}
	// operator-configured upstreams are exempt (exact host, no others)
	f.allowHost("127.0.0.1")
	resp, _, _ := f.Fetch("http://127.0.0.1/x") // real fetch may fail (no server) but must not be screened
	t.Logf("allowed-host fetch err: %v (nil is fine on an active server)", resp)
	if _, _, err := f.Fetch("http://10.0.0.5/x"); err == nil || !strings.Contains(err.Error(), "internal host") {
		t.Errorf("other internal hosts not screened: %v", err)
	}
}

func TestFetcherHostnameScreening(t *testing.T) {
	orig := lookupHost
	t.Cleanup(func() { lookupHost = orig })

	var n int
	uniqueName := func() string {
		n++
		return fmt.Sprintf("screen-test-%d.internal.invalid", n)
	}

	// a name resolving into a private range is screened...
	lookupHost = func(string) ([]string, error) { return []string{"192.168.7.7"}, nil }
	name := uniqueName()
	if !screenInternal(name) {
		t.Fatal("resolving-internal name passed screening")
	}
	f := NewFetcher(false)
	if !f.blockedHost(name) {
		t.Fatal("resolving-internal host not blocked")
	}
	// ...but the operator-configured upstream is exempt
	f.allowHost(name)
	if f.blockedHost(name) {
		t.Fatal("allowed resolving-internal host blocked")
	}

	// a name resolving to public addresses passes screening
	lookupHost = func(string) ([]string, error) { return []string{"93.184.216.34"}, nil }
	if NewFetcher(false).blockedHost(uniqueName()) {
		t.Fatal("public-resolving name blocked")
	}
	// unresolvable: not internal (the dial fails on its own)
	lookupHost = func(string) ([]string, error) { return nil, fmt.Errorf("no such host") }
	if NewFetcher(false).blockedHost(uniqueName()) {
		t.Fatal("unresolvable name blocked as internal")
	}
}

func TestFetcherAllowedHostRedirect(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/x/" {
			w.WriteHeader(http.StatusOK)
			return
		}
		http.Redirect(w, r, "/x/", http.StatusMovedPermanently)
	}))
	defer srv.Close()
	u, err := url.Parse(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	// an operator-configured internal upstream may redirect to itself
	// (http->https / trailing-slash style); the exemption must cover the
	// redirect guard too
	f := NewFetcher(false)
	f.allowHost(u.Host)
	if _, _, err := f.Fetch(srv.URL + "/x"); err != nil {
		t.Fatalf("self-redirect of allowed host blocked: %v", err)
	}
	// without the exemption the same self-redirect is screened
	if _, _, err := NewFetcher(false).Fetch(srv.URL + "/x"); err == nil || !strings.Contains(err.Error(), "internal host") {
		t.Fatalf("self-redirect of unallowed host not screened: %v", err)
	}
}

func TestSizeFits(t *testing.T) {
	// absent Size: no constraint (a Size-less external deb must be storable)
	if !sizeFits(0, "") || !sizeFits(1234, "  ") {
		t.Fatal("empty Size treated as a constraint")
	}
	// explicit sizes still verified
	if sizeFits(100, "200") || !sizeFits(200, "200") || !sizeFits(200, "0") {
		t.Fatal("explicit Size mismatch mishandled")
	}
	// present-but-unparseable size fails closed
	if sizeFits(100, "12ab") {
		t.Fatal("unparseable size accepted")
	}
}

func TestPgpSigned(t *testing.T) {
	if pgpSigned([]byte("Origin: x\nComponents: main\nArchitecture: all\n")) {
		t.Fatal("plain Release flagged signed")
	}
	for _, body := range []string{
		"-----BEGIN PGP SIGNED MESSAGE-----\nHash: SHA256\nOrigin: x\n",
		"Origin: x\n-----BEGIN PGP SIGNATURE-----\naa==\n-----END PGP SIGNATURE-----\n",
	} {
		if !pgpSigned([]byte(body)) {
			t.Fatalf("clearsigned Release not detected:\n%s", body)
		}
	}
}
