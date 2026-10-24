package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path"
	"regexp"
	"strings"
)

type RepoConfig struct {
	URL  string `json:"url"`
	Name string `json:"name,omitempty"`
	// Distribution selects dists-style layout: Release and all index paths
	// resolve against <url>/dists/<distribution>/ and files are stored under
	// <repo>/dists/<distribution>/ so suite-based sources keep working.
	Distribution string `json:"distribution,omitempty"`
	Insecure     bool   `json:"insecure,omitempty"`
}

type Config struct {
	DataDir   string       `json:"dataDir"`
	PublicURL string       `json:"publicUrl"`
	Repos     []RepoConfig `json:"repos"`
}

var nameInvalid = regexp.MustCompile(`[^A-Za-z0-9._-]`)

func deriveRepoName(u *url.URL) string {
	name := u.Host
	trimmed := strings.Trim(u.Path, "/")
	if trimmed != "" {
		parts := strings.Split(path.Clean(trimmed), "/")
		cleaned := make([]string, 0, len(parts))
		for _, p := range parts {
			cleaned = append(cleaned, nameInvalid.ReplaceAllString(p, "_"))
		}
		name += "_" + strings.Join(cleaned, "_")
	}
	return name
}

func loadConfig(cfgPath string) (*Config, error) {
	data, err := os.ReadFile(cfgPath)
	if err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	if cfg.DataDir == "" {
		return nil, errors.New("config: dataDir is required")
	}
	if cfg.PublicURL == "" {
		return nil, errors.New("config: publicUrl is required")
	}
	if len(cfg.Repos) == 0 {
		return nil, errors.New("config: no repos configured")
	}
	seen := map[string]bool{}
	for i := range cfg.Repos {
		repo := &cfg.Repos[i]
		repo.URL = strings.TrimRight(repo.URL, "/")
		u, err := url.Parse(repo.URL)
		if err != nil {
			return nil, fmt.Errorf("config: repo %q invalid url: %w", repo.URL, err)
		}
		if u.Scheme != "http" && u.Scheme != "https" {
			return nil, fmt.Errorf("config: repo %q must be http(s)", repo.URL)
		}
		if repo.Distribution != "" {
			repo.Distribution = path.Clean(repo.Distribution)
			if strings.Contains(repo.Distribution, "..") || strings.ContainsAny(repo.Distribution, "/ \\") {
				return nil, fmt.Errorf("config: repo %q invalid distribution %q", repo.URL, repo.Distribution)
			}
		}
		if repo.Name == "" {
			repo.Name = deriveRepoName(u)
		} else {
			repo.Name = nameInvalid.ReplaceAllString(repo.Name, "_")
		}
		if repo.Name == "." || repo.Name == ".." {
			// path traversal against the dataDir root in sweep/side effects
			return nil, fmt.Errorf("config: repo name %q invalid", repo.Name)
		}
		if seen[repo.Name] {
			return nil, fmt.Errorf("config: duplicate repo name %q", repo.Name)
		}
		seen[repo.Name] = true
	}
	return &cfg, nil
}
