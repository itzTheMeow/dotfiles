package main

import (
	"strings"
	"testing"
)

const spaPage = `<html><head><title>Get pkg by author</title>
<meta property="og:image" content="https://img.example.com/sileo-banner/banner.jpg">
<meta name="og:image" content='https://img.example.com/og/extra.png'>
<script src="../assets/8e6784d14ecb11eb-sentry-init.1afc9.js"></script>
<script>var x=1</script></head>
<body><main id="main"><noscript><img src="https://cdn.example.com/icon/pkg/icon.png"></noscript>
<img data-src="https://lazy.example.com/hero.jpg">
This text is outside the noscript too.
</main></body></html>`

func TestExtractImgCands(t *testing.T) {
	pageURL := "https://repo.example.com/depictions/pkg/pkg.html"
	cands := extractImgCands([]byte(spaPage), pageURL)
	got := strings.Join(cands, "\n")
	want := `https://cdn.example.com/icon/pkg/icon.png
https://img.example.com/og/extra.png
https://img.example.com/sileo-banner/banner.jpg`
	if got != want {
		t.Fatalf("extractImgCands = %q, want %q", got, want)
	}
	// same-origin refs belong to the asset walk, not the image worker
	if same := extractImgCands([]byte(`<img src="pic.png">`), pageURL); len(same) != 0 {
		t.Fatalf("same-host ref must be excluded, got %q", same)
	}
	// data-src is JS-lazy and never renders once scripts are stripped
	if lazy := extractImgCands([]byte(`<img data-src="https://lazy.example.com/hero.jpg">`), pageURL); len(lazy) != 0 {
		t.Fatalf("data-src must be excluded, got %q", lazy)
	}
}

func TestStaticRendition(t *testing.T) {
	pageURL := "https://repo.example.com/depictions/pkg/pkg.html"
	imgs := map[string]string{
		"https://cdn.example.com/icon/pkg/icon.png": "img/icon-hash8.png",
		"https://img.example.com/og/extra.png":      "img/extra-hash8.png",
	}
	static := string(staticRendition([]byte(spaPage), pageURL, imgs))
	if strings.Contains(static, "<script") || strings.Contains(static, "var x=1") {
		t.Fatal("scripts must be stripped:\n" + static)
	}
	if strings.Contains(static, "<noscript") {
		t.Fatal("noscript tags must be unwrapped")
	}
	for _, want := range []string{
		`<img src="../img/icon-hash8.png">`,
		`og:image`,
		`content='../img/extra-hash8.png'`, // mirrored og:image is localized
		`sileo-banner/banner.jpg`,          // unarchived og:image stays hotlinked
		`lazy.example.com/hero.jpg`,        // unmirrored data-src stays untouched
		`This text is outside`,
	} {
		if !strings.Contains(static, want) {
			t.Fatalf("static page missing %q:\n%s", want, static)
		}
	}
}
