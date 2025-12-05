#!/usr/bin/env bash

export RESTIC_COMPRESSION=max
export RESTIC_REPOSITORY=/home/meow/pCloudDrive/Misc/Backups/ipad
export RESTIC_PASSWORD={{ onepasswordRead "op://Private/7kaur74rgd5da4kfcabgy3ahb4/password" }}

SSH_AUTH_SOCK=~/.1password/agent.sock rclone mount ipad:/ /mnt/ipad --read-only --transfers 12 &
RCLONE_PID=$!

# Wait for mount to be ready
echo "Waiting for mount to be ready..."
timeout=30
elapsed=0
while ! mountpoint -q /mnt/ipad && [ $elapsed -lt $timeout ]; do
	sleep 1
	elapsed=$((elapsed + 1))
	echo "Waiting... ($elapsed/$timeout seconds)"
done

if ! mountpoint -q /mnt/ipad; then
	echo "Error: Mount failed or timed out after $timeout seconds"
	kill $RCLONE_PID 2>/dev/null
	exit 1
fi

echo "Mount ready, starting backup..."

restic backup /mnt/ipad \
	--exclude /dev \
	--exclude /proc \
	--exclude /tmp \
	--exclude /System

sleep 1

# Unmount after backup completes
fusermount -u /mnt/ipad 2>/dev/null || umount /mnt/ipad
kill $RCLONE_PID 2>/dev/null
