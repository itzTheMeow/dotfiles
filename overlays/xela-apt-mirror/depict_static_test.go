package main

import (
	"strings"
	"testing"
)

const spaPage = `<html><head><title>Get pkg by author</title>
<meta property="og:image" content="https://img.example.com/sileo-banner/banner.jpg">
<meta name="og:image" content='https://img.example.com/og/extra.png'>
<meta property="og:image" data-content="https://shadow.example.com/x.png" content="https://img.example.com/real-og.png">
<script src="../assets/8e6784d14ecb11eb-sentry-init.1afc9.js"></script>
<script>document.write('<img src="https://js.example.com/tmpl.png">');var x=1</script></head>
<body><main id="main"><noscript><img src="https://cdn.example.com/icon/pkg/icon.png"></noscript>
<img data-src="https://lazy.example.com/hero.jpg">
<img srcset="https://img.example.com/set-1x.png 1x, https://img.example.com/set-2x.png 2x">
<source data-srcset="https://lazy.example.com/srcset.jpg 1x">
This text is outside the noscript too.
</main></body></html>`

func TestExtractImgCands(t *testing.T) {
	pageURL := "https://repo.example.com/depictions/pkg/pkg.html"
	// production extracts from the stripped body (depictions() runs
	// stripDynamic first), so script template img refs are gone already
	cands := extractImgCands(stripDynamic([]byte(spaPage)), pageURL)
	got := strings.Join(cands, "\n")
	want := `https://cdn.example.com/icon/pkg/icon.png
https://img.example.com/og/extra.png
https://img.example.com/real-og.png
https://img.example.com/set-1x.png
https://img.example.com/set-2x.png
https://img.example.com/sileo-banner/banner.jpg`
	if got != want {
		t.Fatalf("extractImgCands = %q, want %q", got, want)
	}
	// same-origin refs belong to the asset walk, not the image worker
	if same := extractImgCands([]byte(`<img src="pic.png">`), pageURL); len(same) != 0 {
		t.Fatalf("same-host ref must be excluded, got %q", same)
	}
	// a leading data-src must not shadow the real src (RE2 leftmost match)
	if both := extractImgCands([]byte(`<img data-src="https://lazy.example.com/one.jpg" src="https://real.example.com/two.png">`), pageURL); len(both) != 1 || both[0] != "https://real.example.com/two.png" {
		t.Fatalf("leading data-src must not shadow the real src, got %q", both)
	}
	// data-src is JS-lazy and never renders once scripts are stripped
	if lazy := extractImgCands([]byte(`<img data-src="https://lazy.example.com/hero.jpg">`), pageURL); len(lazy) != 0 {
		t.Fatalf("data-src must be excluded, got %q", lazy)
	}
	if lazySet := extractImgCands([]byte(`<source data-srcset="https://lazy.example.com/dss.jpg 1x">`), pageURL); len(lazySet) != 0 {
		t.Fatalf("data-srcset must be excluded, got %q", lazySet)
	}
	// data-content must not stand in for content on og:image metas
	if shadow := extractImgCands([]byte(`<meta property="og:image" data-content="https://shadow.example.com/x.png">`), pageURL); len(shadow) != 0 {
		t.Fatalf("data-content must not be read as content, got %q", shadow)
	}
}

func TestStaticRendition(t *testing.T) {
	pageURL := "https://repo.example.com/depictions/pkg/pkg.html"
	imgs := map[string]string{
		"https://cdn.example.com/icon/pkg/icon.png": "img/icon-hash8.png",
		"https://img.example.com/og/extra.png":      "img/extra-hash8.png",
		"https://img.example.com/real-og.png":       "img/realog-hash8.png",
	}
	static := string(staticRendition([]byte(spaPage), pageURL, imgs))
	if strings.Contains(static, "<script") || strings.Contains(static, "var x=1") {
		t.Fatal("scripts must be stripped:\n" + static)
	}
	if strings.Contains(static, "<noscript") {
		t.Fatal("noscript tags must be unwrapped")
	}
	if strings.Contains(static, "js.example.com") {
		t.Fatal("script template img refs must go with the script:\n" + static)
	}
	for _, want := range []string{
		`<img src="../img/icon-hash8.png">`,
		`og:image`,
		`content='../img/extra-hash8.png'`, // mirrored og:image is localized
		`content="../img/realog-hash8.png"`,
		`sileo-banner/banner.jpg`,   // unarchived og:image stays hotlinked
		`lazy.example.com/hero.jpg`, // unmirrored data-src stays untouched
		`set-1x.png 1x`,             // unmirrored srcset stays intact
		`This text is outside`,
	} {
		if !strings.Contains(static, want) {
			t.Fatalf("static page missing %q:\n%s", want, static)
		}
	}
}
