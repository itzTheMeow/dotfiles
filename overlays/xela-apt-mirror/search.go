package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

// SearchEntry is one package row in the aggregated cross-repo index
type SearchEntry struct {
	ID   string `json:"id"`
	Name string `json:"n"`
	Repo string `json:"r"`
}

// searchDoc is the compact wire form: repo-name -> full packages.html URL
// map plus one short entry per package (indices not needed, names are small)
type searchDoc struct {
	Repos map[string]string `json:"r"`
	Pkgs  []SearchEntry     `json:"p"`
}

// writeSearchIndex persists a repo's shard under _search/ for the landing
// merge; called from writeBrowserArtifacts so fresh data always wins
func writeSearchIndex(dataDir, repo string, pkgs []BrowserPackage) error {
	if err := os.MkdirAll(filepath.Join(dataDir, "_search"), 0o755); err != nil {
		return err
	}
	entries := make([]SearchEntry, 0, len(pkgs))
	for _, p := range pkgs {
		name := p.Name
		if name == "" {
			name = p.ID
		}
		entries = append(entries, SearchEntry{ID: p.ID, Name: name, Repo: repo})
	}
	raw, err := json.Marshal(entries)
	if err != nil {
		return err
	}
	return writeAtomic(filepath.Join(dataDir, "_search", repo+".json"), raw)
}

// mergeSearchIndex folds every fresh shard into the root search.json; shards
// whose repo is gone are removed so removed repos stop being searchable
func mergeSearchIndex(dataDir string, manifests []*RepoManifest) error {
	repos := map[string]string{}
	for _, m := range manifests {
		if m == nil {
			continue
		}
		repos[m.Name] = m.Mirror + "/packages.html"
	}
	shardDir := filepath.Join(dataDir, "_search")
	shards, err := os.ReadDir(shardDir)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	doc := searchDoc{Repos: map[string]string{}}
	for _, s := range shards {
		name := strings.TrimSuffix(s.Name(), ".json")
		keep, ok := repos[name]
		if !ok {
			os.Remove(filepath.Join(shardDir, s.Name()))
			continue
		}
		doc.Repos[name] = keep
		raw, err := os.ReadFile(filepath.Join(shardDir, s.Name()))
		if err != nil {
			continue
		}
		var entries []SearchEntry
		if json.Unmarshal(raw, &entries) != nil {
			continue
		}
		doc.Pkgs = append(doc.Pkgs, entries...)
	}
	raw, err := json.Marshal(doc)
	if err != nil {
		return err
	}
	return writeAtomic(filepath.Join(dataDir, "search.json"), raw)
}

// renderSearchHTML builds the static cross-repo search page; ES3-only JS so
// iOS 4/5 era Safari can run it (JSON.parse guarded with try/catch)
func renderSearchHTML() string {
	const pageJS = `<script>
var REPOS={},PKG=[],loaded=false;
function esc(s){var d=document.createElement('div');d.appendChild(document.createTextNode(''+s));return d.innerHTML;}
function fail(m){var el=document.getElementById('st');el.innerHTML='<div class="muted">'+m+'</div>';}
function load(){
 fail('loading index...');
 var x=new XMLHttpRequest();
 x.open('GET','search.json',true);
 x.onreadystatechange=function(){
  if(x.readyState!=4)return;
  if(x.status!=200){fail('index unavailable ('+x.status+')');return}
  var j=null;try{j=JSON.parse(x.responseText)}catch(e){}
  if(!j||!j.p){fail('index unreadable');return}
  REPOS=j.r;PKG=j.p;loaded=true;
  run();
 };
 x.send(null);
}
function run(){
 var q=document.getElementById('q').value.toLowerCase();
 var out=document.getElementById('out');
 var n=0,html='',LIMIT=300;
 for(var i=0;i<PKG.length&&n<LIMIT;i++){
  var e=PKG[i];
  if(!e.id)continue;
  var hay=(e.n+' '+e.id).toLowerCase();
  if(q&&hay.indexOf(q)<0)continue;
  n++;
  html+='<div class="row"><a href="'+esc(REPOS[e.r]||'/')+'"><b>'+esc(e.n)+'</b> <code>'+esc(e.id)+'</code></a><div class="meta">in '+esc(e.r)+'</div></div>';
 }
 if(n==0){out.innerHTML='';fail('no match');return}
 var st=document.getElementById('st');
 st.innerHTML='<div class="meta">'+n+(n>=LIMIT?' shown of more':'')+' match'+(n==1?'':'es')+'</div>';
 out.innerHTML='<div class="box">'+html+'</div>';
}
function sync(){if(loaded)run()}
</script>`
	s := `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Search - iOS APT Mirrors</title><style>` +
		baseCSS + `</style></head><body><div class="page">` +
		`<p class="meta"><a href="/">← all mirrors</a></p>` +
		`<h1>Search Packages</h1>` +
		`<div id="st" class="center"></div>` +
		`<input id="q" class="searchbox" type="text" placeholder="Search name or package id&hellip;" onkeyup="sync()" onfocus="if(!loaded)load()" autofocus="autofocus">` +
		`<div id="out"></div>` +
		`<noscript><div class="box"><div class="row"><div class="muted">Search needs JavaScript; use each repo's package list instead.</div></div></div></noscript>` +
		`<p class="center"><a href="#" onclick="return toggleTheme()">⌾ dark mode</a></p>` +
		`</div>` + pageJS + themeScript + `</body></html>`
	return s
}
