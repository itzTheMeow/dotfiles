package main

import (
	"flag"
	"log"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"
)

func main() {
	cfgPath := flag.String("config", "", "path to JSON config")
	sweepOnly := flag.Bool("sweep-only", false, "run nothing but the repo/pool garbage sweep")
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
	// flock the data dir for the whole run: systemd already serializes the
	// service, but a manual --sweep-only racing a running sync could sweep
	// a just-downloaded pool entry whose symlink does not exist yet
	lock, err := os.OpenFile(filepath.Join(cfg.DataDir, "_lock"), os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		log.Fatalf("lock: %v", err)
	}
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		log.Fatalf("another apt-mirror run appears active; refusing to start")
	}
	defer lock.Close()
	if *sweepOnly {
		sweep(cfg)
		return
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
	sweep(cfg)
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
