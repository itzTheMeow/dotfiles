package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

var ignoredFiles = []string{
	".directory",
}

func formatFolderName(t time.Time) string {
	return fmt.Sprintf("%02d-%s", t.Month(), t.Format("January"))
}

func main() {
	if len(os.Args) < 2 || os.Args[1] == "" {
		fmt.Println("Specify a directory to organize into!")
		os.Exit(1)
	}

	base := os.Args[1]
	if _, err := os.Stat(base); os.IsNotExist(err) {
		fmt.Printf("Directory \"%s\" doesn't exist.\n", base)
		os.Exit(1)
	}

	src := base
	if len(os.Args) > 2 && os.Args[2] != "" {
		src = os.Args[2]
	}
	if _, err := os.Stat(src); os.IsNotExist(err) {
		fmt.Printf("Source directory \"%s\" doesn't exist.\n", src)
		os.Exit(1)
	}

	entries, err := os.ReadDir(src)
	if err != nil {
		fmt.Printf("Failed to read directory: %v\n", err)
		os.Exit(1)
	}

	for _, entry := range entries {
		name := entry.Name()
		filePath := filepath.Join(src, name)

		info, err := entry.Info()
		if err != nil {
			fmt.Printf("Failed to get info for %s: %v\n", name, err)
			continue
		}

		// ignore any 4-digit-year directories (2000, 2023, etc)
		if len(name) == 4 && entry.IsDir() {
			if _, err := strconv.Atoi(name); err == nil {
				continue
			}
		}

		// ignore specific file names
		if info.Mode().IsRegular() {
			skip := false
			for _, ignored := range ignoredFiles {
				if name == ignored {
					skip = true
					break
				}
			}
			if skip {
				continue
			}
		}

		mtime := info.ModTime()
		monthFolder := formatFolderName(mtime)

		yearDir := filepath.Join(base, strconv.Itoa(mtime.Year()))
		if _, err := os.Stat(yearDir); os.IsNotExist(err) {
			if err := os.Mkdir(yearDir, 0755); err != nil {
				fmt.Printf("Failed to create year directory: %v\n", err)
				continue
			}
		}

		monthDir := filepath.Join(yearDir, monthFolder)
		if _, err := os.Stat(monthDir); os.IsNotExist(err) {
			if err := os.Mkdir(monthDir, 0755); err != nil {
				fmt.Printf("Failed to create month directory: %v\n", err)
				continue
			}
		}

		ext := filepath.Ext(name)
		baseName := strings.TrimSuffix(name, ext)
		newPath := filepath.Join(monthDir, name)
		ct := 1

		for {
			if _, err := os.Stat(newPath); os.IsNotExist(err) {
				break
			}
			newPath = filepath.Join(monthDir, fmt.Sprintf("%s-%d%s", baseName, ct, ext))
			ct++
		}

		// Move the file
		if err := os.Rename(filePath, newPath); err != nil {
			fmt.Printf("Failed to move %s: %v\n", filePath, err)
			continue
		}
		fmt.Printf("%s => %s\n", filePath, newPath)
	}

	fmt.Println("Done.")
}
