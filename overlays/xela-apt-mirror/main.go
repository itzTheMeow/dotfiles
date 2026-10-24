package main

import (
	"flag"
	"log"
	"os"
	"sync"
	"time"
)

func main() {
	cfgPath := flag.String("config", "", "path to JSON config")
	flag.Parse()
	log.SetFlags(log.LstdFlags)
	log.SetOutput(activityWriter{os.Stderr})
	startWatchdog(envDuration("APTM_WATCHDOG_MAX", 105*time.Minute))
	cfg, err := loadConfig(*cfgPath)
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	if err := os.MkdirAll(cfg.DataDir, 0o755); err != nil {
		log.Fatalf("data dir: %v", err)
	}
	now := time.Now()
	manifests := make([]*RepoManifest, len(cfg.Repos))
	var wg sync.WaitGroup
	for i, repo := range cfg.Repos {
		wg.Add(1)
		go func(i int, r RepoConfig) {
			defer wg.Done()
			manifests[i] = syncOne(cfg, r, now)
		}(i, repo)
	}
	wg.Wait()
	if err := generateLanding(cfg, manifests); err != nil {
		log.Printf("landing: %v", err)
	}
	failed := 0
	for _, m := range manifests {
		if m == nil || m.Status == statusFailed {
			failed++
		}
	}
	if failed == len(cfg.Repos) {
		os.Exit(1)
	}
}
