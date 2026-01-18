#!/usr/bin/env bash
# Clean up rustic log file by removing timestamps and adding duration

LOG_FILE="/tmp/rustic.log"

if [[ ! -f "$LOG_FILE" ]]; then
	exit 0
fi

# Read the log file into an array
mapfile -t lines <"$LOG_FILE"

if [[ ${#lines[@]} -eq 0 ]]; then
	exit 0
fi

# Extract first and last timestamps
first_line="${lines[0]}"
last_line="${lines[-1]}"

# Extract timestamps (ISO 8601 format with nanoseconds)
first_ts="${first_line%%Z*}Z"
last_ts="${last_line%%Z*}Z"

# Convert timestamps to seconds (removing nanoseconds for simplicity)
first_epoch=$(date -d "${first_ts%.*}Z" +%s 2>/dev/null)
last_epoch=$(date -d "${last_ts%.*}Z" +%s 2>/dev/null)

# Calculate duration
duration=$((last_epoch - first_epoch))

# Clear the log file and write cleaned output
echo -n "" >"$LOG_FILE"

for line in "${lines[@]}"; do
	# Remove timestamp (everything before and including '] ')
	cleaned="${line#*] }"
	echo "$cleaned" >>"$LOG_FILE"
done

# Add duration at the end if we could calculate it
if [[ -n "$duration" && "$duration" -ge 0 ]]; then
	echo "Total time: ${duration}s" >>"$LOG_FILE"
fi

# send notification
NTFY_TOPIC="$NTFY_TOPIC-backups" ntfy publish -t "Rustic Backup Complete" "$(cat $LOG_FILE)"
