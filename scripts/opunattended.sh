#!/usr/bin/env bash
# Allows getting a locally cached op secret for automation.

set -euo pipefail

if [ $# -eq 0 ]; then
	echo "Usage: $0 <secret-reference>" >&2
	echo "Example: $0 'op://vault/item/field'" >&2
	exit 1
fi

SECRET_REF="$1"
CACHE_DIR="${HOME}/.cache/opunattended"

# Normalize the secret reference to a filename using SHA256 hash
CACHE_FILENAME=$(echo -n "$SECRET_REF" | sha256sum | cut -d' ' -f1)
CACHE_FILE="${CACHE_DIR}/${CACHE_FILENAME}"

# If the file exists, use it.
if [ -f "$CACHE_FILE" ]; then
	cat "$CACHE_FILE"
else
	# Otherwise fallback to op read.
	op read "$SECRET_REF"
fi
