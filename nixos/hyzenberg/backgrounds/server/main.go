package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"hash/fnv"
	"html/template"
	stdimage "image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"log"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	defaultRefresh = 4 * time.Hour
	browserUA      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
	maxCacheBytes  = 256 << 20 // 256 MiB of proxied image bytes
)

// config passed from nix
type config struct {
	URLs           []string `json:"urls"`
	RefreshSeconds int      `json:"refreshSeconds"`
}
func (c config) refresh() time.Duration {
	if c.RefreshSeconds > 0 {
		return time.Duration(c.RefreshSeconds) * time.Second
	}
	return defaultRefresh
}

// a scraped photo page
type image struct {
	Source      string `json:"source"` // original page as configured
	Host        string `json:"host"`   // Pixabay / Unsplash
	ImageURL    string `json:"imageUrl"`
	Author      string `json:"author"`
	AuthorURL   string `json:"authorUrl,omitempty"`
	PageURL     string `json:"pageUrl"`
	Description string `json:"description,omitempty"`
	Width       int    `json:"width,omitempty"`
	Height      int    `json:"height,omitempty"`
}

// holds the current image set and a small cache of proxied bytes
type store struct {
	cfg    config
	state  string
	client *http.Client

	mu     sync.RWMutex
	images []image

	imgMu    sync.Mutex
	imgBytes map[string][]byte
	imgSize  int
	imgOrder []string
}

func newStore(cfg config, state string) (*store, error) {
	jar, err := cookiejar.New(nil)
	if err != nil {
		return nil, err
	}
	return &store{
		cfg:      cfg,
		state:    state,
		client:   &http.Client{Jar: jar, Timeout: 60 * time.Second},
		imgBytes: map[string][]byte{},
	}, nil
}

var (
	challengeRe = regexp.MustCompile(`(?s)<script[^>]*id="anubis_challenge"[^>]*>(.*?)</script>`)
	ldJSONRe    = regexp.MustCompile(`(?s)<script type="application/ld\+json">(.*?)</script>`)
	ogImageRe   = regexp.MustCompile(`(?is)<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']`)
	contentURL  = regexp.MustCompile(`content=["']([^"']+)["'][^>]+property=["']og:image["']`)
)

type anubisChallenge struct {
	Rules struct {
		Algorithm  string `json:"algorithm"`
		Difficulty int    `json:"difficulty"`
	} `json:"rules"`
	Challenge struct {
		ID         string `json:"id"`
		RandomData string `json:"randomData"`
	} `json:"challenge"`
}

type ldPerson struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type ldImage struct {
	Type               string   `json:"@type"`
	ContentURL         string   `json:"contentUrl"`
	Author             ldPerson `json:"author"`
	Creator            ldPerson `json:"creator"`
	AcquireLicensePage string   `json:"acquireLicensePage"`
	Description        string   `json:"description"`
	Name               string   `json:"name"`
}

// fetchGET performs a GET with browser-like headers, transparently solving an
// Anubis challenge if one is returned. The response body is always returned
// (even for non-2xx) so callers can inspect challenges.
func (s *store) fetchGET(ctx context.Context, rawurl string) ([]byte, error) {
	body, _, err := s.doGET(ctx, rawurl, true)
	return body, err
}

func (s *store) doGET(ctx context.Context, rawurl string, allowSolve bool) ([]byte, string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawurl, nil)
	if err != nil {
		return nil, "", err
	}
	setBrowserHeaders(req)

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 16<<20))
	if err != nil {
		return nil, "", err
	}

	if allowSolve {
		if m := challengeRe.FindSubmatch(body); m != nil && solveAnubis(ctx, s.client, rawurl, m[1]) {
			return s.doGET(ctx, rawurl, false)
		}
	}
	if resp.StatusCode >= 400 {
		return body, resp.Header.Get("Content-Type"), fmt.Errorf("GET %s: %s", rawurl, resp.Status)
	}
	return body, resp.Header.Get("Content-Type"), nil
}

func setBrowserHeaders(req *http.Request) {
	req.Header.Set("User-Agent", browserUA)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("Upgrade-Insecure-Requests", "1")
	req.Header.Set("Sec-Fetch-Dest", "document")
	req.Header.Set("Sec-Fetch-Mode", "navigate")
	req.Header.Set("Sec-Fetch-Site", "none")
}

// solveAnubis computes the proof-of-work and exchanges it for a pass cookie via
// the jar on client. Returns true if the challenge was solved.
func solveAnubis(ctx context.Context, client *http.Client, rawurl string, payload []byte) bool {
	var ch anubisChallenge
	if err := json.Unmarshal(payload, &ch); err != nil {
		log.Printf("anubis: bad challenge json: %v", err)
		return false
	}
	if ch.Rules.Algorithm != "fast" {
		log.Printf("anubis: unsupported algorithm %q", ch.Rules.Algorithm)
		return false
	}
	data := ch.Challenge.RandomData
	prefix := strings.Repeat("0", ch.Rules.Difficulty)

	nonce := 0
	response := ""
	for {
		sum := sha256.Sum256([]byte(data + strconv.Itoa(nonce)))
		h := hex.EncodeToString(sum[:])
		if strings.HasPrefix(h, prefix) {
			response = h
			break
		}
		nonce++
		if ctx.Err() != nil {
			return false
		}
	}

	u, err := url.Parse(rawurl)
	if err != nil {
		return false
	}
	pass := url.URL{
		Scheme: u.Scheme,
		Host:   u.Host,
		Path:   "/.within.website/x/cmd/anubis/api/pass-challenge",
	}
	q := pass.Query()
	q.Set("id", ch.Challenge.ID)
	q.Set("response", response)
	q.Set("nonce", strconv.Itoa(nonce))
	q.Set("redir", u.RequestURI())
	q.Set("elapsedTime", "1")
	pass.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, pass.String(), nil)
	if err != nil {
		return false
	}
	setBrowserHeaders(req)
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("anubis: pass-challenge failed: %v", err)
		return false
	}
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
	log.Printf("anubis: solved challenge for %s (nonce=%d)", u.Host, nonce)
	return true
}

func hostName(rawurl string) string {
	u, err := url.Parse(rawurl)
	if err != nil {
		return ""
	}
	h := strings.ToLower(u.Host)
	switch {
	case strings.Contains(h, "pixabay"):
		return "Pixabay"
	case strings.Contains(h, "unsplash"):
		return "Unsplash"
	default:
		return u.Host
	}
}

// scrape resolves a photo page into an image with attribution.
func (s *store) scrape(ctx context.Context, rawurl string) (image, error) {
	body, err := s.fetchGET(ctx, rawurl)
	if err != nil {
		return image{}, err
	}

	img := image{Source: rawurl, Host: hostName(rawurl), PageURL: rawurl}

	for _, m := range ldJSONRe.FindAllSubmatch(body, -1) {
		var candidate ldImage
		if err := json.Unmarshal(m[1], &candidate); err != nil {
			// @graph / arrays: try the generic map form below
			var generic any
			if json.Unmarshal(m[1], &generic) == nil {
				candidate = findImageObject(generic)
			}
		}
		if candidate.Type == "ImageObject" && candidate.ContentURL != "" {
			img.ImageURL = candidate.ContentURL
			img.Author = firstNonEmpty(candidate.Author.Name, candidate.Creator.Name)
			img.AuthorURL = firstNonEmpty(candidate.Author.URL, candidate.Creator.URL)
			img.Description = firstNonEmpty(candidate.Description, candidate.Name)
			if candidate.AcquireLicensePage != "" {
				img.PageURL = candidate.AcquireLicensePage
			}
			break
		}
	}

	if img.ImageURL == "" {
		if m := ogImageRe.FindSubmatch(body); m != nil {
			img.ImageURL = string(m[1])
		} else if m := contentURL.FindSubmatch(body); m != nil {
			img.ImageURL = string(m[1])
		}
	}
	if img.ImageURL == "" {
		return image{}, errors.New("no image url found")
	}
	// html/template escapes &, but the source may contain raw & in urls.
	img.ImageURL = strings.ReplaceAll(img.ImageURL, "&amp;", "&")
	normalizeImageURL(&img)
	s.fillDimensions(ctx, &img)
	return img, nil
}

// fillDimensions downloads the image (warming the proxy cache) and records its
// pixel dimensions so the landing page can show the served resolution.
func (s *store) fillDimensions(ctx context.Context, img *image) {
	data, _, err := s.getImageBytes(ctx, img.ImageURL)
	if err != nil {
		log.Printf("dimensions %s: %v", img.ImageURL, err)
		return
	}
	cfg, _, err := stdimage.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		log.Printf("decode config %s: %v", img.ImageURL, err)
		return
	}
	img.Width, img.Height = cfg.Width, cfg.Height
}

// normalizeImageURL bounds the resolution of imgix-backed (Unsplash) images so
// a full-screen background isn't a 9MB download, and pins the format to jpeg so
// the served image is always decodable by the standard library. Pixabay's
// JSON-LD already points at a modest _1280 variant.
func normalizeImageURL(img *image) {
	u, err := url.Parse(img.ImageURL)
	if err != nil || !strings.Contains(strings.ToLower(u.Host), "unsplash") {
		return
	}
	q := u.Query()
	q.Del("auto") // don't let imgix pick avif/webp based on Accept
	q.Set("fm", "jpg")
	q.Set("fit", "crop")
	q.Set("w", "2560")
	q.Set("q", "70")
	u.RawQuery = q.Encode()
	img.ImageURL = u.String()
}

// findImageObject walks a decoded JSON value looking for an ImageObject.
func findImageObject(v any) ldImage {
	switch t := v.(type) {
	case []any:
		for _, e := range t {
			if img := findImageObject(e); img.ContentURL != "" {
				return img
			}
		}
	case map[string]any:
		if t["@type"] == "ImageObject" {
			b, _ := json.Marshal(t)
			var img ldImage
			if json.Unmarshal(b, &img) == nil && img.ContentURL != "" {
				return img
			}
		}
		for _, e := range t {
			if img := findImageObject(e); img.ContentURL != "" {
				return img
			}
		}
	}
	return ldImage{}
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

func (s *store) scrapeAll(ctx context.Context) []image {
	out := make([]image, 0, len(s.cfg.URLs))
	for i, u := range s.cfg.URLs {
		img, err := s.scrape(ctx, u)
		if err != nil {
			log.Printf("scrape %s: %v", u, err)
			// keep the last known-good entry for this url
			if old, ok := s.lookup(u); ok {
				out = append(out, old)
			}
			continue
		}
		out = append(out, img)
		if i < len(s.cfg.URLs)-1 {
			select {
			case <-ctx.Done():
				return out
			case <-time.After(time.Second):
			}
		}
	}
	return out
}

func (s *store) lookup(src string) (image, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, img := range s.images {
		if img.Source == src {
			return img, true
		}
	}
	return image{}, false
}

func (s *store) setImages(imgs []image) {
	s.mu.Lock()
	s.images = imgs
	s.mu.Unlock()
}

func (s *store) loadState() {
	b, err := os.ReadFile(filepath.Join(s.state, "images.json"))
	if err != nil {
		return
	}
	var imgs []image
	if json.Unmarshal(b, &imgs) == nil && len(imgs) > 0 {
		s.setImages(imgs)
		log.Printf("loaded %d cached images", len(imgs))
	}
}

func (s *store) saveState() {
	s.mu.RLock()
	imgs := s.images
	s.mu.RUnlock()
	b, err := json.MarshalIndent(imgs, "", "  ")
	if err != nil {
		return
	}
	_ = os.WriteFile(filepath.Join(s.state, "images.json"), b, 0o644)
}

func (s *store) run(ctx context.Context) {
	s.loadState()

	doRefresh := func() {
		rctx, cancel := context.WithTimeout(ctx, 10*time.Minute)
		defer cancel()
		imgs := s.scrapeAll(rctx)
		if len(imgs) > 0 {
			s.setImages(imgs)
			s.saveState()
			log.Printf("refreshed %d/%d images", len(imgs), len(s.cfg.URLs))
		}
	}
	doRefresh()

	ticker := time.NewTicker(s.cfg.refresh())
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			doRefresh()
		}
	}
}

func (s *store) pick(bucket int64, seed string) (image, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if len(s.images) == 0 {
		return image{}, false
	}
	h := fnv.New64a()
	fmt.Fprintf(h, "%d\x00%s", bucket, seed)
	return s.images[h.Sum64()%uint64(len(s.images))], true
}

func (s *store) remaining() int {
	now := time.Now().Unix()
	r := int64(s.cfg.refresh().Seconds())
	return int(r - now%r)
}

func (s *store) getImageBytes(ctx context.Context, imageURL string) ([]byte, string, error) {
	s.imgMu.Lock()
	if b, ok := s.imgBytes[imageURL]; ok {
		s.imgMu.Unlock()
		return b, contentTypeFor(imageURL), nil
	}
	s.imgMu.Unlock()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, imageURL, nil)
	if err != nil {
		return nil, "", err
	}
	req.Header.Set("User-Agent", browserUA)
	req.Header.Set("Accept", "image/avif,image/webp,image/*,*/*;q=0.8")
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return nil, "", fmt.Errorf("image GET %s: %s", imageURL, resp.Status)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, 64<<20))
	if err != nil {
		return nil, "", err
	}
	ctype := resp.Header.Get("Content-Type")
	if ctype == "" {
		ctype = contentTypeFor(imageURL)
	}

	s.imgMu.Lock()
	s.imgBytes[imageURL] = data
	s.imgSize += len(data)
	s.imgOrder = append(s.imgOrder, imageURL)
	for s.imgSize > maxCacheBytes && len(s.imgOrder) > 0 {
		old := s.imgOrder[0]
		s.imgOrder = s.imgOrder[1:]
		if b, ok := s.imgBytes[old]; ok {
			s.imgSize -= len(b)
			delete(s.imgBytes, old)
		}
	}
	s.imgMu.Unlock()

	return data, ctype, nil
}

func contentTypeFor(imageURL string) string {
	u, err := url.Parse(imageURL)
	if err != nil {
		return "image/jpeg"
	}
	switch strings.ToLower(filepath.Ext(u.Path)) {
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".avif":
		return "image/avif"
	default:
		return "image/jpeg"
	}
}

var gridTmpl = template.Must(template.New("grid").Parse(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Backgrounds</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 2rem; background: #1e1e2e; color: #cdd6f4;
         font: 14px/1.5 system-ui, -apple-system, sans-serif; }
  h1 { margin: 0 0 .25rem; font-size: 1.4rem; }
  .sub { margin: 0 0 1.5rem; color: #9399b2; }
  .sub a { color: #89b4fa; }
  .grid { display: grid; gap: 1rem; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); }
  figure { margin: 0; }
  figure img { width: 100%; aspect-ratio: 3/2; object-fit: cover; border-radius: 8px;
               display: block; background: #313244; }
  figcaption { margin-top: .4rem; font-size: .85rem; color: #a6adc8; }
  figcaption a { color: #89b4fa; text-decoration: none; }
  .seed { color: #6c7086; }
</style>
</head>
<body>
<h1>Backgrounds</h1>
<p class="sub">{{len .Images}} images &middot; shuffles every {{.Refresh}} &middot; <a href="/current">/current</a></p>
<div class="grid">
{{range .Images}}
  <figure>
    <a href="{{.PageURL}}" target="_blank" rel="noopener"><img src="{{.ImageURL}}" loading="lazy" alt="{{.Description}}"></a>
    <figcaption>Photo by <a href="{{.PageURL}}" target="_blank" rel="noopener">{{.Author}}</a> on {{.Host}}{{if .Width}} &middot; {{.Width}}&times;{{.Height}}{{end}}</figcaption>
  </figure>
{{end}}
</div>
</body>
</html>
`))

func (s *store) handleGrid(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	s.mu.RLock()
	imgs := append([]image(nil), s.images...)
	s.mu.RUnlock()
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = gridTmpl.Execute(w, struct {
		Images  []image
		Refresh string
	}{imgs, s.cfg.refresh().String()})
}

func (s *store) handleCurrent(w http.ResponseWriter, r *http.Request) {
	seed := strings.TrimPrefix(r.URL.Path, "/current")
	seed = strings.Trim(seed, "/")
	if decoded, err := url.PathUnescape(seed); err == nil {
		seed = decoded
	}
	asJSON := strings.HasSuffix(seed, ".json")
	if asJSON {
		seed = strings.TrimSuffix(seed, ".json")
	}
	if seed == "" {
		seed = "0"
	}

	bucket := time.Now().Unix() / int64(s.cfg.refresh().Seconds())
	img, ok := s.pick(bucket, seed)
	if !ok {
		if asJSON {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = io.WriteString(w, `{"error":"no images available yet"}`)
		} else {
			http.Error(w, "no images available yet", http.StatusServiceUnavailable)
		}
		return
	}

	if asJSON {
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", s.remaining()))
		w.Header().Set("Access-Control-Allow-Origin", "*")
		_ = json.NewEncoder(w).Encode(img)
		return
	}

	data, ctype, err := s.getImageBytes(r.Context(), img.ImageURL)
	if err != nil {
		log.Printf("proxy %s: %v", img.ImageURL, err)
		http.Error(w, "failed to fetch image", http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", ctype)
	w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", s.remaining()))
	w.Header().Set("X-Image-Author", img.Author)
	w.Header().Set("X-Image-Source", img.PageURL)
	_, _ = w.Write(data)
}

func main() {
	cfgPath := os.Getenv("BACKGROUNDS_CONFIG")
	state := envOr("BACKGROUNDS_STATE_DIR", "/var/lib/backgrounds")
	addr := envOr("BACKGROUNDS_ADDR", ":8080")

	cfg := config{}
	if cfgPath != "" {
		b, err := os.ReadFile(cfgPath)
		if err != nil {
			log.Fatalf("read config %s: %v", cfgPath, err)
		}
		if err := json.Unmarshal(b, &cfg); err != nil {
			log.Fatalf("parse config %s: %v", cfgPath, err)
		}
	}
	if len(cfg.URLs) == 0 {
		log.Fatal("no urls configured")
	}
	if err := os.MkdirAll(state, 0o755); err != nil {
		log.Fatalf("state dir %s: %v", state, err)
	}

	st, err := newStore(cfg, state)
	if err != nil {
		log.Fatal(err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go st.run(ctx)

	mux := http.NewServeMux()
	mux.HandleFunc("/", st.handleGrid)
	mux.HandleFunc("/current", st.handleCurrent)
	mux.HandleFunc("/current.json", st.handleCurrent)
	mux.HandleFunc("/current/", st.handleCurrent)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(w, "ok\n")
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("backgrounds listening on %s (%d urls, refresh %s)", addr, len(cfg.URLs), cfg.refresh())
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func envOr(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}
