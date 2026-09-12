#!/usr/bin/env bash
set -euo pipefail

# orphaned.sh [--full] [host] [anchors.json]
#
# List files/dirs under /z (persistent btrfs storage) that are not linked
# anywhere by the current impermanence config. Ground truth is config-derived:
# the anchor set from the persist module (see persist.linkPaths in
# modules/persist.nix):
#   dirs  -> bind-mounted directories; every descendant of one is live data
#   files -> bind-mounted individual files
# plus all scaffolding parent directories required to keep the mounts alive.
#
# Orphans are reported once per subtree root with du sizes; --full lists every
# orphaned path. Nothing is ever deleted.
#
# Needs read access to /z (run via `sudo`, as nx orphaned does).

full=0
if [[ "${1:-}" == "--full" ]]; then
	full=1
	shift
fi

host="${1:-${HOSTNAME:-}}"
[[ -n "$host" ]] || {
	echo "error: no host given" >&2
	exit 2
}

json_file="${2:-}"

if [[ -n "$json_file" ]]; then
	json="$(cat "$json_file")"
else
	json="$(nix eval --json ".#nixosConfigurations.${host}.config.persist.linkPaths")"
fi

[[ -d /z ]] || {
	echo "error: no /z on this system" >&2
	exit 1
}
command -v jq >/dev/null || {
	echo "error: jq is required" >&2
	exit 1
}

declare -A dirroots=()
declare -A chain=()

# mark a path and all its ancestors up to /z as scaffolding
mark_chain() { # path
	local p="$1"
	while [[ "$p" != "/z" && "$p" != "/" ]]; do
		chain["$p"]=1
		p="${p%/*}"
	done
	chain["/z"]=1
}

while IFS= read -r p; do
	[[ -n "$p" ]] || continue
	dirroots["$p"]=1
	mark_chain "$p"
done < <(jq -r '.dirs[]' <<<"$json")

while IFS= read -r p; do
	[[ -n "$p" ]] || continue
	mark_chain "$p"
done < <(jq -r '.files[]' <<<"$json")

orphans=0

walk() { # dir
	local d="$1" c
	while IFS= read -r c; do
		# bind-mounted dir: everything beneath it is live, skip the whole tree
		[[ -z "${dirroots[$c]+x}" ]] || continue
		if [[ -n "${chain[$c]+x}" ]]; then
			[[ -d "$c" ]] && walk "$c"
			continue
		fi
		# orphaned: report the subtree root once
		((orphans += 1))
		if ((full)); then
			printf '%s\n' "$c"
			[[ -d "$c" ]] && find "$c" -xdev -mindepth 1 2>/dev/null || true
		else
			du -sh "$c" 2>/dev/null || printf '%s\n' "$c"
		fi
	done < <(find "$d" -mindepth 1 -maxdepth 1 2>/dev/null)
}

echo "# orphans under /z ($host)"
walk /z
printf 'found %d orphaned subtree roots\n' "$orphans"
