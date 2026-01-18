#!/usr/bin/env bash
# Mounts the ipad over sftp.

# make sure directory exists
mkdir -p /mnt/pcloud
# and is unmounted
fusermount -u /mnt/pcloud 2>/dev/null || umount /mnt/pcloud || true

# then actually mount rclone
rclone mount pcloud:/ /mnt/pcloud \
	--daemon \
	--read-only \
	--buffer-size 64M \
	--transfers 16 \
	--checkers 8 \
	--dir-cache-time 5m
