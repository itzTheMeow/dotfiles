#!/usr/bin/env bash
# Mounts the ipad over sftp.

# make sure directory exists
mkdir -p /mnt/ipad
# and is unmounted
fusermount -u /mnt/ipad 2>/dev/null || umount /mnt/ipad || true

# then actually mount rclone
rclone mount ipad:/ /mnt/ipad \
	--daemon \
	--read-only \
	--vfs-read-chunk-size 128M \
	--vfs-read-chunk-size-limit off \
	--buffer-size 128M \
	--transfers 16 \
	--checkers 16 \
	--sftp-concurrency 16
