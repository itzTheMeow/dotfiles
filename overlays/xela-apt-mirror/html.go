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

const baseCSS = `
body{background:#1e1e2e;color:#cdd6f4;font-family:-apple-system,'Helvetica Neue',Helvetica,Arial,sans-serif;margin:0}
a{color:#89b4fa;text-decoration:none}
a:visited{color:#b4befe}
.wrap{max-width:880px;margin:0 auto;padding:16px}
.repo{background:#313244;border:1px solid #45475a;border-radius:12px;padding:14px 18px;margin:14px 0}
.repo h2{margin:0 0 4px;font-size:18px}
.repo h2 a{color:#cba6f7}
.muted{color:#a6adc8;font-size:14px}
.meta{color:#a6adc8;font-size:13px;margin:4px 0}
.desc{margin:8px 0;font-size:14px}
table.links{width:100%;border-collapse:collapse;margin-top:10px}
table.links th{text-align:left;color:#a6adc8;font-size:12px;font-weight:normal;padding:2px 4px;width:70px;vertical-align:top}
table.links td{border-top:1px solid #45475a;padding:6px 4px;vertical-align:top;font-size:13px}
code{background:#45475a;border-radius:4px;padding:2px 5px;font-family:Menlo,Consolas,'Courier New',monospace;font-size:12px;word-break:break-all}
.badge{display:inline-block;border-radius:8px;padding:1px 8px;font-size:12px;margin-right:4px}
.b-ok{background:rgba(166,227,161,.18);color:#a6e3a1}
.b-missing{background:rgba(243,139,168,.18);color:#f38ba8}
.b-locked{background:rgba(249,226,175,.18);color:#f9e2af}
.pak{background:#313244;border:1px solid #45475a;border-radius:10px;padding:10px 14px;margin:10px 0}
.pak table{width:100%;border-collapse:collapse}
.pak td.ic{width:44px;vertical-align:top}
.pak td.ic img{width:40px;height:40px;border-radius:8px}
.ver{border-top:1px solid #45475a;padding:6px 0;font-size:13px;margin-top:6px}
.search{background:#181825;border:1px solid #45475a;border-radius:8px;color:#cdd6f4;font-size:15px;padding:8px 10px;width:60%;max-width:340px}
h1{color:#f5c2e7;font-size:22px}
`

func clientLinksTable(mirror string) string {
	m := esc(mirror)
	src := mirror + "/"
	cydia := "https://cydia.saurik.com/api/share#?source=" + src
	var b strings.Builder
	b.WriteString(`<table class="links">`)
	b.WriteString(`<tr><th>Cydia</th><td><a href="cydia://` + esc(cydia) + `">` + esc(cydia) + `</a></td></tr>`)
	b.WriteString(`<tr><th>Sileo</th><td><a href="sileo://source/` + m + `">sileo://source/` + m + `</a></td></tr>`)
	b.WriteString(`<tr><th>Zebra</th><td><a href="zebra://` + m + `">zebra://` + m + `</a></td></tr>`)
	b.WriteString(`</table>`)
	return b.String()
}

func renderLandingHTML(data LandingData) string {
	var b strings.Builder
	b.WriteString(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>iOS APT Mirrors</title><style>`)
	b.WriteString(baseCSS)
	b.WriteString(`</style></head><body><div class="wrap">`)
	b.WriteString(`<h1>iOS APT Repositories</h1>`)
	b.WriteString(`<p class="muted">Local archive of legacy iOS repositories, synced daily. Open a source link with Cydia, Sileo or Zebra on your device.</p>`)

	var versions int
	var logical int64
	for _, m := range data.Repos {
		if m == nil {
			continue
		}
		versions += m.Versions
		logical += m.LogicalSize
	}
	b.WriteString(`<p class="muted">` + esc(itoa(int64(len(data.Repos)))) + ` repos · ` + esc(itoa(int64(versions))) + ` package versions · ` +
		esc(humanSize(logical)) + ` referenced · pool ` + esc(humanSize(data.Pool.Bytes)) + ` across ` + esc(itoa(int64(data.Pool.Files))) + ` files · generated ` + esc(data.Generated) + `</p>`)

	for _, m := range data.Repos {
		if m == nil {
			continue
		}
		b.WriteString(`<div class="repo">`)
		status := `<span class="badge b-ok">` + esc(m.Status) + `</span>`
		if m.Status == statusStale {
			status = `<span class="badge b-locked">stale - upstream unreachable, serving last copy</span>`
		} else if m.Status == statusFailed {
			status = `<span class="badge b-missing">failed - ` + esc(m.Error) + `</span>`
		}
		b.WriteString(`<h2><a href="` + esc(m.Mirror) + `/">` + esc(m.Name) + `</a> ` + status + `</h2>`)
		if m.Release != nil {
			meta := []string{}
			if o := m.Release["label"]; o != "" {
				meta = append(meta, esc(o))
			} else if o := m.Release["origin"]; o != "" {
				meta = append(meta, esc(o))
			}
			if s := m.Release["suite"]; s != "" {
				meta = append(meta, esc(s))
			}
			if d := m.Release["date"]; d != "" {
				meta = append(meta, "release index of "+esc(d))
			}
			if len(meta) != 0 {
				b.WriteString(`<div class="meta">` + strings.Join(meta, " · ") + `</div>`)
			}
			if d := m.Release["description"]; d != "" {
				b.WriteString(`<div class="desc">` + esc(d) + `</div>`)
			}
		}
		flags := `<span class="badge b-ok">` + esc(itoa(int64(m.OK))) + ` debs</span>`
		if m.Missing != nil && len(m.Missing) != 0 {
			flags += ` <span class="badge b-missing">` + esc(itoa(int64(len(m.Missing)))) + ` unavailable</span>`
		}
		if m.Locked != nil && len(m.Locked) != 0 {
			flags += ` <span class="badge b-locked">` + esc(itoa(int64(len(m.Locked)))) + ` paid</span>`
		}
		b.WriteString(`<div class="meta">` + flags + `<span class="muted">` + esc(itoa(int64(m.Unique))) + ` packages · ` + esc(itoa(int64(m.Versions))) + ` versions · ` + esc(humanSize(m.LogicalSize)) + ` · synced ` + esc(m.Updated) + `</span></div>`)
		b.WriteString(clientLinksTable(m.Mirror))
		b.WriteString(`<div class="meta"><a href="` + esc(m.Mirror) + `/packages.html">package list</a> · <a href="` + esc(m.Mirror) + `/">raw repo files</a> · upstream: ` + esc(m.URL) + `</div>`)
		b.WriteString(`</div>`)
	}
	b.WriteString(`<p class="muted">Byte-faithful mirrors with original repository signatures; nothing is ever removed from the archive.</p>`)
	b.WriteString(`</div></body></html>`)
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
	return writeAtomic(filepath.Join(repoDir, "packages.html"), []byte(renderRepoHTML(pkg)))
}

func renderRepoHTML(pkg *BrowserData) string {
	var b strings.Builder
	b.WriteString(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>`)
	b.WriteString(esc(pkg.Name))
	b.WriteString(` - iOS APT Mirror</title><style>`)
	b.WriteString(baseCSS)
	b.WriteString(`</style></head><body><div class="wrap">`)
	b.WriteString(`<div class="meta"><a href="/">← all mirrors</a> · upstream: <a href="` + esc(pkg.Upstream) + `">` + esc(pkg.Upstream) + `</a> · <a href="/` + esc(pkg.Name) + `/">raw repo files</a></div>`)
	b.WriteString(`<h1>` + esc(pkg.Name) + ` · repositories bytes</h1>`)
	meta := []string{}
	for _, k := range []string{"origin", "label", "suite", "codename"} {
		if v := pkg.Release[k]; v != "" {
			meta = append(meta, esc(v))
		}
	}
	if len(meta) != 0 {
		b.WriteString(`<div class="meta">` + strings.Join(meta, " · ") + `</div>`)
	}
	b.WriteString(`<p class="muted">` + esc(itoa(int64(pkg.Unique))) + ` packages · synced ` + esc(pkg.Synced) + ` · filter: <input class="search" type="text" onkeyup="filter(this)" placeholder="type to filter"></p>`)
	for _, p := range pkg.Packages {
		search := strings.ToLower(p.ID + " " + p.Name + " " + p.Description + " " + p.Section)
		b.WriteString(`<div class="pak" data-s="` + esc(search) + `"><table><tr>`)
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
	b.WriteString(`<script>function filter(t){var v=t.value.toLowerCase();var d=document.getElementsByTagName('div');for(var i=0;i<d.length;i++){var c=' '+d[i].className+' ';if(c.indexOf(' pak ')<0){continue;}var s=d[i].getAttribute('data-s')||'';d[i].style.display=(s.indexOf(v)>=0)?'':'none';}}</script>`)
	b.WriteString(`</div></body></html>`)
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
	return writeAtomic(filepath.Join(cfg.DataDir, "index.html"), []byte(renderLandingHTML(data)))
}
