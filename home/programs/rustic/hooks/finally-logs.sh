#!/usr/bin/env bash
# Log latest snapshot information to ntfy from rustic.

format_int() {
	printf "%'d" "$1"
}

format_bytes() {
	numfmt --to=iec-i --suffix=B "$1"
}

# get snapshot json data
SNAPSHOT_JSON=$(rustic -P "$1" snapshots latest --json)

# extract all values in 1 pass
read -r FILES_NEW FILES_CHANGED FILES_UNMODIFIED \
	DIRS_NEW DIRS_CHANGED DIRS_UNMODIFIED \
	DATA_ADDED DATA_ADDED_PACKED \
	TOTAL_FILES_PROCESSED TOTAL_BYTES_PROCESSED \
	TOTAL_DURATION SNAPSHOT_TIME SNAPSHOT_ID <<<"$(
		jq -r '
			.[0].snapshots[0] as $s
			| $s.summary as $sum
			| [
					$sum.files_new,
					$sum.files_changed,
					$sum.files_unmodified,

					$sum.dirs_new,
					$sum.dirs_changed,
					$sum.dirs_unmodified,

					$sum.data_added,
					$sum.data_added_packed,

					$sum.total_files_processed,
					$sum.total_bytes_processed,

					$sum.total_duration,
					$s.time,
					($s.id[0:8])
				]
			| @tsv
		' <<<"$SNAPSHOT_JSON"
	)"

# format times
TIMESTAMP=$(date -d "$SNAPSHOT_TIME" '+%b %-d, %Y %-I:%M%P')
DURATION_ROUNDED=$(printf "%.2f" "$TOTAL_DURATION")

# construct message
MESSAGE="$TIMESTAMP - Took ${DURATION_ROUNDED}s
Data Added: $(format_bytes "$DATA_ADDED_PACKED") ($(format_bytes "$DATA_ADDED") raw)
Files:  $(format_int "$FILES_NEW") new, $(format_int "$FILES_CHANGED") changed, $(format_int "$FILES_UNMODIFIED") unchanged
Dirs:   $(format_int "$DIRS_NEW") new, $(format_int "$DIRS_CHANGED") changed, $(format_int "$DIRS_UNMODIFIED") unchanged
processed $(format_int "$TOTAL_FILES_PROCESSED") files, $(format_bytes "$TOTAL_BYTES_PROCESSED")
snapshot $SNAPSHOT_ID saved"

# send notification
NTFY_TOPIC="$NTFY_TOPIC-backups" ntfy publish -t "Backup Complete ($1)" "$MESSAGE"
