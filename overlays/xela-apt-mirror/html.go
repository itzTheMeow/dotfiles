package main

import (
	"encoding/json"
	"html"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type PoolStats struct {
	Files int   `json:"files"`
	Bytes int64 `json:"bytes"`
}

type LandingData struct {
	Generated string          `json:"generated"`
	Pool      PoolStats       `json:"pool"`
	Logical   int64           `json:"logicalBytes"`
	Repos     []*RepoManifest `json:"repos"`
}

func esc(s string) string { return html.EscapeString(s) }

func poolStats(dataDir string) PoolStats {
	var ps PoolStats
	entries, err := os.ReadDir(filepath.Join(dataDir, "_pool"))
	if err != nil {
		return ps
	}
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".deb") {
			continue
		}
		if fi, err := e.Info(); err == nil {
			ps.Files++
			ps.Bytes += fi.Size()
		}
	}
	return ps
}

func statusBadge(status, reason string) string {
	class := map[string]string{statusOK: "b-ok", statusMissing: "b-missing", statusLocked: "b-locked"}[status]
	if status == statusLocked {
		return `<span class="badge b-locked" title="` + esc(reason) + `">paid</span>`
	}
	if class == "" {
		return ""
	}
	label := map[string]string{statusOK: "ok", statusMissing: "unavailable"}[status]
	if reason != "" && status != statusOK {
		label += " · " + esc(reason)
	}
	return `<span class="badge ` + class + `">` + label + `</span>`
}

// baseCSS is a hand-rolled iOS-grouped-list look using only constructs
// old-dead Safari (iOS 4/5/6 era) renders correctly: floats/inline-block,
// no flex/grid/custom-properties; dark theme toggles via body.dark class
const baseCSS = `
body{background:#eff0f2;color:#222;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;margin:0;-webkit-text-size-adjust:100%}
body.dark{background:#17191d;color:#e8eaee}
.page{max-width:680px;margin:0 auto;padding:0 10px 44px}
h1{font-size:22px;font-weight:bold;text-align:center;margin:20px 0 4px}
h2{font-size:12px;letter-spacing:.06em;text-transform:uppercase;font-weight:normal;color:#8a8f98;text-align:center;margin:22px 6px 6px}
body.dark h2{color:#9aa0ab}
.box{background:#fff;border:1px solid rgba(0,0,0,.06);border-radius:12px;margin:0 0 14px}
body.dark .box{background:#232630;border-color:#383c46}
.row{padding:10px 14px;border-bottom:1px solid #e8e8ea;word-wrap:break-word}
.row:last-child{border-bottom:0}
body.dark .row{border-bottom-color:#383c46}
.center{text-align:center}
.meta{font-size:12px;color:#8a8f98}
body.dark .meta{color:#9aa0ab}
.muted{font-size:13px;color:#8a8f98}
body.dark .muted{color:#9aa0ab}
.desc{margin:4px 0;font-size:14px}
a{color:#0a66ff;text-decoration:none}
body.dark a{color:#7fb1ff}
code{font-family:Menlo,Consolas,'Courier New',monospace;font-size:12px;background:rgba(0,0,0,.05);border-radius:4px;padding:1px 5px;word-break:break-all}
body.dark code{background:rgba(255,255,255,.08)}
.badge{display:inline-block;border-radius:8px;padding:1px 8px;font-size:12px;margin-right:4px}
.b-ok{background:rgba(52,168,80,.15);color:#1e8e3e}
.b-missing{background:rgba(234,67,53,.14);color:#d93025}
.b-locked{background:rgba(251,188,4,.18);color:#b06000}
body.dark .b-ok{color:#81c995;background:rgba(52,168,80,.18)}
body.dark .b-missing{color:#f28b82;background:rgba(234,67,53,.18)}
body.dark .b-locked{color:#fdd663;background:rgba(251,188,4,.18)}
table.btns{border-collapse:collapse;margin:0 auto}
table.btns td{padding:2px 12px;text-align:center}
table.btns img{width:58px;height:58px;border-radius:13px;display:block;margin:0 auto 6px;border:1px solid rgba(0,0,0,.06)}
table.btns label{display:block;font-size:13px}
.searchbox{width:100%;-webkit-box-sizing:border-box;box-sizing:border-box;font-size:16px;padding:9px 12px;border:1px solid #cfd2d8;border-radius:10px;background:#fff;color:#222;margin:6px 0}
body.dark .searchbox{background:#232630;border-color:#3a3e48;color:#e8eaee}
.pak table{width:100%;border-collapse:collapse}
.pak td.ic{width:48px;vertical-align:top}
.pak td.ic img{width:40px;height:40px;border-radius:8px}
.ver{border-top:1px solid #e8e8ea;padding:6px 0;font-size:13px;margin-top:6px}
body.dark .ver{border-top-color:#383c46}
.ver:first-child{border-top:0;margin-top:0}
`

// appButtonsHTML renders the Cydia/Sileo/Zebra "open source" button row;
// icons come from /assets/apps/ (copied there by the service unit)
func appButtonsHTML(mirror string) string {
	cydia := "cydia://url/https://cydia.saurik.com/api/share#?source=" + mirror + "/"
	sileo := "sileo://source/" + mirror
	zebra := "zbra://sources/add/" + mirror
	var b strings.Builder
	b.WriteString(`<table class="btns"><tr>`)
	for _, app := range []struct{ name, icon, href string }{
		{"Cydia", "/assets/apps/cydia.png", cydia},
		{"Sileo", "/assets/apps/sileo.png", sileo},
		{"Zebra", "/assets/apps/zebra.png", zebra},
	} {
		t := `<td><a href="` + esc(app.href) + `"><img src="` + esc(app.icon) + `" alt="` + esc(app.name) + `"><label>` + esc(app.name) + `</label></a></td>`
		b.WriteString(t)
	}
	b.WriteString(`</tr></table>`)
	return b.String()
}

// themeScript is the ES3-safe dark-mode bootstrap: stored preference wins,
// else device prefers-color-scheme, try/catch guards private-browsing
// localStorage throws
const themeScript = `<script>
function darkPref(){var ok=false;try{ok=!!(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches)}catch(e){}return ok}
function setDark(d){document.body.className=d?'dark':'';try{localStorage.setItem('am-theme',d?'dark':'light')}catch(e){}}
function toggleTheme(){setDark(document.body.className!=='dark');return false}
(function(){var t=null;try{t=localStorage.getItem('am-theme')}catch(e){}if(t=='dark'||(t===null&&darkPref()))setDark(true)})();
</script>`

func renderLandingHTML(data LandingData) string {
	var b strings.Builder
	b.WriteString(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>iOS APT Mirrors</title><style>`)
	b.WriteString(baseCSS)
	b.WriteString(`</style></head><body><div class="page">`)
	b.WriteString(`<h1>iOS APT Mirrors</h1>`)
	b.WriteString(`<p class="muted center">Archives of legacy iOS repositories, synced daily.</p>`)

	var versions int
	var logical int64
	for _, m := range data.Repos {
		if m == nil {
			continue
		}
		versions += m.Versions
		logical += m.LogicalSize
	}
	b.WriteString(`<p class="meta center">` + esc(itoa(int64(len(data.Repos)))) + ` repos · ` + esc(itoa(int64(versions))) + ` versions · ` +
		esc(humanSize(logical)) + ` referenced · generated ` + esc(data.Generated) + `</p>`)

	b.WriteString(`<h2>Search</h2>`)
	b.WriteString(`<div class="box"><div class="row"><a href="/search.html">Search all packages across every repo</a></div></div>`)

	b.WriteString(`<h2>Repos</h2>`)
	for _, m := range data.Repos {
		if m == nil {
			continue
		}
		b.WriteString(`<div class="box">`)
		var status string
		if m.Status == statusStale {
			status = ` <span class="badge b-locked">stale</span>`
		} else if m.Status == statusFailed {
			status = ` <span class="badge b-missing">failed</span>`
		}
		b.WriteString(`<div class="row"><a href="` + esc(m.Mirror) + `/packages.html"><b>` + esc(m.Name) + `</b></a>` + status + `</div>`)
		if m.Release != nil {
			meta := []string{}
			if o := m.Release["label"]; o != "" {
				meta = append(meta, esc(o))
			} else if o := m.Release["origin"]; o != "" {
				meta = append(meta, esc(o))
			}
			if len(meta) != 0 {
				b.WriteString(`<div class="row"><div class="meta">` + strings.Join(meta, " · ") + `</div></div>`)
			}
		}
		flags := `<span class="badge b-ok">` + esc(itoa(int64(m.OK))) + ` debs</span>`
		if m.Missing != nil && len(m.Missing) != 0 {
			flags += ` <span class="badge b-missing">` + esc(itoa(int64(len(m.Missing)))) + ` unavailable</span>`
		}
		if m.Locked != nil && len(m.Locked) != 0 {
			flags += ` <span class="badge b-locked">` + esc(itoa(int64(len(m.Locked)))) + ` paid</span>`
		}
		links := ` · <a href="` + esc(m.Mirror) + `/packages.html">package list</a> · <a href="` + esc(m.Mirror) + `/">repo files</a> · <a href="` + esc(m.URL) + `">upstream</a>`
		b.WriteString(`<div class="row"><div class="meta">` + flags + `<br>` + esc(itoa(int64(m.Unique))) + ` packages · ` + esc(itoa(int64(m.Versions))) + ` versions · ` + esc(humanSize(m.LogicalSize)) + ` · synced ` + esc(m.Updated) + `<br>` + links + `</div></div>`)
		b.WriteString(`</div>`)
	}
	b.WriteString(`<h2>Notes</h2>`)
	b.WriteString(`<div class="box"><div class="row"><div class="muted">Byte-faithful mirrors with original repository signatures; nothing is ever removed from the archive.</div></div></div>`)
	b.WriteString(`<p class="center"><a href="#" onclick="return toggleTheme()">⌾ dark mode</a></p>`)
	b.WriteString(`</div>` + themeScript + `</body></html>`)
	return b.String()
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }

func writeBrowserArtifacts(dataDir string, pkg *BrowserData) error {
	repoDir := filepath.Join(dataDir, pkg.Name)
	raw, err := json.MarshalIndent(pkg, "", "  ")
	if err != nil {
		return err
	}
	if err := writeAtomic(filepath.Join(repoDir, "packages.json"), raw); err != nil {
		return err
	}
	if err := writeSearchIndex(dataDir, pkg.Name, pkg.Packages); err != nil {
		return err
	}
	return writeAtomic(filepath.Join(repoDir, "packages.html"), []byte(renderRepoHTML(pkg)))
}

func renderRepoHTML(pkg *BrowserData) string {
	var b strings.Builder
	b.WriteString(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>`)
	b.WriteString(esc(pkg.Name))
	b.WriteString(` - iOS APT Mirror</title><style>`)
	b.WriteString(baseCSS)
	b.WriteString(`</style></head><body><div class="page">`)
	b.WriteString(`<p class="meta"><a href="/">← all mirrors</a> · <a href="` + esc(pkg.Mirror) + `/">repo files</a> · upstream: <a href="` + esc(pkg.Upstream) + `">` + esc(pkg.Upstream) + `</a></p>`)
	b.WriteString(`<h1>` + esc(pkg.Name) + `</h1>`)
	meta := []string{}
	seenMeta := map[string]bool{}
	for _, k := range []string{"origin", "label", "suite", "codename"} {
		if v := pkg.Release[k]; v != "" && !seenMeta[v] {
			seenMeta[v] = true
			meta = append(meta, esc(v))
		}
	}
	if len(meta) != 0 {
		b.WriteString(`<p class="muted center">` + strings.Join(meta, " · ") + `</p>`)
	}
	b.WriteString(`<h2>Open in&hellip;</h2>`)
	b.WriteString(appButtonsHTML(pkg.Mirror))
	b.WriteString(`<h2 class="pkg">Packages (` + esc(itoa(int64(pkg.Unique))) + `)</h2>`)
	b.WriteString(`<p class="meta">synced ` + esc(pkg.Synced) + `</p>`)
	b.WriteString(`<input class="searchbox" type="text" onkeyup="filter(this)" placeholder="Filter this repo&hellip;">`)
	for _, p := range pkg.Packages {
		search := strings.ToLower(p.ID + " " + p.Name + " " + p.Description + " " + p.Section)
		b.WriteString(`<div class="box pak" data-s="` + esc(search) + `"><table><tr>`)
		if p.Icon != "" {
			b.WriteString(`<td class="ic"><img src="` + esc(p.Icon) + `" alt=""></td>`)
		} else {
			b.WriteString(`<td class="ic"></td>`)
		}
		b.WriteString(`<td>`)
		name := p.Name
		if name == "" {
			name = p.ID
		}
		b.WriteString(`<b>` + esc(name) + `</b> <code>` + esc(p.ID) + `</code>`)
		if p.Section != "" {
			b.WriteString(` <span class="muted">` + esc(p.Section) + `</span>`)
		}
		if p.Description != "" {
			b.WriteString(`<div class="desc">` + esc(p.Description) + `</div>`)
		}
		if p.Homepage != "" {
			b.WriteString(`<div class="meta">homepage: <a href="` + esc(p.Homepage) + `">` + esc(p.Homepage) + `</a></div>`)
		}
		for _, v := range p.Versions {
			link := ""
			if v.Deb != "" {
				link = ` · <a href="` + esc(v.Deb) + `">.deb</a>`
			}
			dep := ""
			for _, r := range v.Depictions {
				if r.Archived != "" {
					linkArchived := r.Archived
					if id := depictID(r.Original); id != "" {
						linkArchived += "?id=" + url.QueryEscape(id)
					}
					dep += ` · <a href="` + esc(linkArchived) + `">description</a>`
				}
				dep += ` · <a href="` + esc(r.Original) + `">upstream page</a>`
			}
			b.WriteString(`<div class="ver">`)
			b.WriteString(statusBadge(v.Status, v.Reason) + ` ` + esc(v.Version) + ` · ` + esc(humanSize(v.Size)) + link + dep)
			if v.Compat != "" {
				b.WriteString(` · <span class="muted">` + esc(v.Compat) + `</span>`)
			}
			if v.Author != "" {
				b.WriteString(` · <span class="muted">` + esc(v.Author) + `</span>`)
			}
			if v.Shasum != "" && len(v.Shasum) > 16 {
				b.WriteString(` <code title="sha256">` + esc(v.Shasum[:16]) + `…</code>`)
			}
			b.WriteString(`</div>`)
		}
		b.WriteString(`</td></tr></table></div>`)
	}
	b.WriteString(`<p class="center"><a href="#" onclick="return toggleTheme()">⌾ dark mode</a></p>`)
	b.WriteString(`<script>function filter(t){var v=t.value.toLowerCase();var d=document.getElementsByTagName('div');for(var i=0;i<d.length;i++){var c=' '+d[i].className+' ';if(c.indexOf(' pak ')<0){continue;}var s=d[i].getAttribute('data-s')||'';d[i].style.display=(s.indexOf(v)>=0)?'':'none';}}</script>`)
	b.WriteString(`</div>` + themeScript + `</body></html>`)
	return b.String()
}

func generateLanding(cfg *Config, manifests []*RepoManifest) error {
	data := LandingData{Generated: formatTime(time.Now()), Pool: poolStats(cfg.DataDir)}
	for _, m := range manifests {
		if m == nil {
			continue
		}
		data.Repos = append(data.Repos, m)
		data.Logical += m.LogicalSize
	}
	raw, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}
	if err := writeAtomic(filepath.Join(cfg.DataDir, "repos.json"), raw); err != nil {
		return err
	}
	if err := mergeSearchIndex(cfg.DataDir, manifests); err != nil {
		return err
	}
	if err := writeAtomic(filepath.Join(cfg.DataDir, "search.html"), []byte(renderSearchHTML())); err != nil {
		return err
	}
	return writeAtomic(filepath.Join(cfg.DataDir, "index.html"), []byte(renderLandingHTML(data)))
}
