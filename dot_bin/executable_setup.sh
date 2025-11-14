#!/bin/bash

####################
#     setup.sh     #
#   by Meow 2025   #
####################
# Script to install various tools on a new linux machine.

set -e
cd ~

PROMPT=(whiptail --separate-output --checklist "Choose packages to install" 20 78 10)

# extracts script title from script
get_title() {
	local file="$1"
	local base desc
	base="$(basename "$file" .sh)"
	# extract title from '##' line (fallback to basename)
	desc="$(awk '/^##/{sub(/^##[[:space:]]*/,"",$0); print; exit}' "$file" 2>/dev/null || true)"
	if [ -z "$desc" ]; then
		printf '%s' "$base"
	else
		printf '%s' "$desc"
	fi
}

OPTIONS=()
for f in ./.bin/setup/*.sh; do
	# make sure theres actually files
	[ -e "$f" ] || continue
	OPTIONS+=("$(basename "$f" .sh)" "$(get_title "$f")" ON)
done

CHOICES=$("${PROMPT[@]}" "${OPTIONS[@]}" 2>&1 >/dev/tty)

if [ -z "$CHOICES" ]; then
	echo "No scripts selected!"
fi

# update/install packages
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y bzip2 unzip wget
sudo apt-get autoremove -y

if [ -n "$CHOICES" ]; then
	while IFS= read -r choice; do
		[ -z "$choice" ] && continue
		cd ~
		script_path="./.bin/setup/${choice}.sh"
		if [ ! -f "$script_path" ]; then
			echo "warning: script not found: $script_path"
			continue
		fi
		echo "running $(get_title "$script_path")..."
		bash "$script_path"
	done <<EOF
$CHOICES
EOF
fi
