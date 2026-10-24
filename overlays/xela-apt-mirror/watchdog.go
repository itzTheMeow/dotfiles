package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"runtime"
	"sync/atomic"
	"time"
)

// silenceWatch max auto-configurable idle; env for tests
var watchdogIdle = envDuration("APTM_WATCHDOG_IDLE", 15*time.Minute)

var lastOutput atomic.Int64

// activityWriter wraps a writer (stderr) and feeds the watchdog: any
// log line through any logger counts as the process being alive
type activityWriter struct {
	inner io.Writer
}

func (w activityWriter) Write(p []byte) (int, error) {
	n, err := w.inner.Write(p)
	lastOutput.Store(time.Now().UnixNano())
	return n, err
}

// dumpStacks prints every goroutine's stack so a silent hang diagnoses
// itself from the journald output
func dumpStacks(reason string) {
	buf := make([]byte, 1<<20)
	for {
		n := runtime.Stack(buf, true)
		if n < len(buf) {
			buf = buf[:n]
			break
		}
		buf = make([]byte, 2*len(buf))
	}
	log.Printf("watchdog: %s; dumping all goroutine stacks:\n%s", reason, buf)
}

// startWatchdog watches for output silence above watchdogIdle and for a
// total runtime above maxRuntime; on the latter it dumps and exits since
// a hung run must not waste the systemd window
func startWatchdog(maxRuntime time.Duration) {
	lastOutput.Store(time.Now().UnixNano())
	go func() {
		start := time.Now()
		tick := watchdogIdle / 4
		if tick > 30*time.Second {
			tick = 30 * time.Second
		}
		if maxRuntime > 0 && maxRuntime < tick {
			tick = maxRuntime / 4
		}
		next := time.NewTicker(tick)
		for now := range next.C {
			if maxRuntime > 0 && now.Sub(start) >= maxRuntime {
				dumpStacks(fmt.Sprintf("hard deadline %v reached", maxRuntime))
				log.Print("watchdog: exiting before systemd timeout cuts this run off blind")
				os.Exit(3)
			}
			idle := now.UnixNano() - lastOutput.Load()
			if idle > watchdogIdle.Nanoseconds() {
				dumpStacks(fmt.Sprintf("no output for %.0f minutes", float64(idle)/float64(time.Minute)))
				lastOutput.Store(now.UnixNano())
			}
		}
	}()
}

func envDuration(name string, def time.Duration) time.Duration {
	if v := os.Getenv(name); v != "" {
		if d, err := time.ParseDuration(v); err == nil && d > 0 {
			return d
		}
		log.Printf("watchdog: bad %s %q, using %v", name, v, def)
	}
	return def
}
