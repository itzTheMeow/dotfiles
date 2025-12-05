#!/usr/bin/env bash

export AWS_ACCESS_KEY_ID={{ onepasswordRead "op://Private/Backblaze/Application Keys/xela-codes-nas-id" }}
export AWS_SECRET_ACCESS_KEY="op://Private/Backblaze/Application Keys/xela-codes-nas-applicationKey"

export RESTIC_COMPRESSION=max
export RESTIC_REPOSITORY=s3:s3.us-east-005.backblazeb2.com/xela-codes-nas
export RESTIC_PASSWORD="op://Private/Backblaze Restic Repo/password"

LOG_FILE="/tmp/restic_$(date +"%Y-%m-%d_%H-%M-%S").log"
MOUNTPOINT="/mnt/pcloud"

# log into 1password
eval $(op signin)

# make sure mountpoint exists
mkdir -p "$MOUNTPOINT"

# Start rclone in background if not already mounted. Capture PID so we can clean up.
RC_RCLONE_PID=""
if ! mountpoint -q "$MOUNTPOINT"; then
	# Start rclone in background and redirect its logs to the same log file
	nohup rclone mount pcloud: "$MOUNTPOINT" --read-only --buffer-size 64M --transfers 16 --checkers 8 --dir-cache-time 5m >>"$LOG_FILE" 2>&1 &
	RC_RCLONE_PID=$!

	# Wait up to 30 seconds for the mount to appear
	TIMEOUT=30
	SECONDS_WAIT=0
	until mountpoint -q "$MOUNTPOINT" || [ $SECONDS_WAIT -ge $TIMEOUT ]; do
		sleep 1
		SECONDS_WAIT=$((SECONDS_WAIT + 1))
	done

	if ! mountpoint -q "$MOUNTPOINT"; then
		echo "rclone mount failed to appear within ${TIMEOUT}s, aborting" >&2
		kill $RC_RCLONE_PID 2>/dev/null || true
		exit 1
	fi

	echo "rclone mounted" >&2
fi

# Cleanup function: unmount and kill rclone if we started it.
cleanup() {
	if [ -n "$RC_RCLONE_PID" ]; then
		# Kill rclone first to stop any ongoing operations
		kill $RC_RCLONE_PID 2>/dev/null || true
		# Give it a moment to exit cleanly
		sleep 1
	fi

	if mountpoint -q "$MOUNTPOINT"; then
		# Wait a bit for any file operations to complete
		sleep 2
		# Try to unmount gracefully; fallback to lazy unmount
		fusermount -u "$MOUNTPOINT" 2>/dev/null || umount -l "$MOUNTPOINT" 2>/dev/null || true
	fi
}

# Ensure cleanup runs on exit or interruption
trap cleanup EXIT INT TERM

echo "backing up..." >&2
op run -- restic backup "$MOUNTPOINT" "$@" 2>&1 | tee -a $LOG_FILE

if command -v ntfy &>/dev/null; then
	NTFY_TOPIC="$NTFY_TOPIC-backups" ntfy publish -t "Restic Backup Complete" "$(cat $LOG_FILE)"
fi
