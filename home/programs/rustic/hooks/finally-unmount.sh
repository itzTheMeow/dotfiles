#!/usr/bin/env bash
# Unmounts a specific directory.

echo "Unmounting..." | tee -a "$LOG_FILE"
if fusermount -u "$1" 2>/dev/null || umount "$1"; then
	echo "Successfully unmounted $1" | tee -a "$LOG_FILE"
else
	echo "Failed to unmount $1" | tee -a "$LOG_FILE"
fi
