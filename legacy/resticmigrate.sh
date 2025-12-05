#!/bin/bash

set -euo pipefail

# Prompt for backup name and password
read -rp "Enter a name for the backup (used as hostname and repo name): " BACKUP_NAME
read -rsp "Enter password for the restic repository: " RESTIC_PASSWORD
echo

# Set environment variables
export RESTIC_PASSWORD
export RESTIC_COMPRESSION=max
export RESTIC_REPOSITORY="$(pwd)/${BACKUP_NAME}"

# Initialize the repository if it doesn't exist
if [ ! -d "$RESTIC_REPOSITORY" ]; then
	echo "Initializing restic repository at $RESTIC_REPOSITORY..."
	restic init
fi

# Find all .tar.gz files with date in the filename
FILES=()
while IFS= read -r -d '' file; do
	FILES+=("$file")
done < <(find . -maxdepth 1 -type f -name "*.tar.gz" -regextype posix-extended -regex ".*/.*[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz" -print0)

if [ ${#FILES[@]} -eq 0 ]; then
	echo "No matching .tar.gz files with a date found in the current directory."
	exit 1
fi

# Create a temporary extraction directory
TMPDIR=$(mktemp -d)
trap "rm -rf \"$TMPDIR\"" EXIT

# Sort files
FILES_SORTED=($(for file in "${FILES[@]}"; do
	echo "$file"
done | sort -t'-' -k1,1 -k2,2 -k3,3))

# Loop through each file
for FILE in "${FILES_SORTED[@]}"; do
	echo "Processing $FILE..."

	BASENAME=$(basename "$FILE")

	# Extract date from filename
	if [[ "$BASENAME" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
		SNAPSHOT_DATE="${BASH_REMATCH[1]}"
	else
		echo "Skipping $BASENAME: no valid date found."
		continue
	fi

	# Extract the archive to temporary directory
	EXTRACT_DIR="$TMPDIR/${BASENAME%.tar.gz}"
	mkdir -p "$EXTRACT_DIR"
	tar -xzf "$FILE" -C "$EXTRACT_DIR"

	cp /usr/bin/restic "$EXTRACT_DIR"

	# Create a snapshot with backdated timestamp and custom host
	echo "Creating snapshot for $BASENAME dated $SNAPSHOT_DATE..."
	proot \
		-b "$EXTRACT_DIR:/backup" \
		restic backup /backup \
		--no-cache \
		--host "$BACKUP_NAME" \
		--time "$SNAPSHOT_DATE 00:00:00"

	echo "Snapshot for $BASENAME complete."
done

echo "All snapshots completed."
