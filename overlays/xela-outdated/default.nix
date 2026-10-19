final: prev: {
  xela-outdated = final.callPackage (
    {
      coreutils,
      gawk,
      jq,
      nix,
      writeShellApplication,
    }:
    writeShellApplication {
      name = "xela-outdated";
      runtimeInputs = [
        coreutils
        gawk
        jq
        nix
      ];
      text = ''
        set -euo pipefail

        usage() {
          cat <<'EOF'
        usage: xela-outdated [--host HOST] [--all]

        check directly-used packages against the upstream nixpkgs channels.
        locked revisions come from flake.lock; tips from channels.nixos.org.

          --host HOST   only include HOST (default: every host in the flake)
          --all         also show up-to-date and unmapped packages
          -h, --help    show this help
        EOF
        }

        flake="''${DOTFILES:-$PWD}"
        onlyHost=""
        showAll=false

        while [ $# -gt 0 ]; do
          case "$1" in
            --host)
              [ $# -ge 2 ] || { echo "xela-outdated: --host needs an argument" >&2; exit 1; }
              onlyHost="$2"
              shift 2
              ;;
            --all)
              showAll=true
              shift
              ;;
            -h | --help)
              usage
              exit 0
              ;;
            *)
              echo "xela-outdated: unknown argument: $1" >&2
              usage >&2
              exit 1
              ;;
          esac
        done

        flake=$(readlink -f "$flake")
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT

        # stage 0 - host list; attrNames doesn't force host configs
        allhosts=$(
          nix eval --impure --json --expr "builtins.attrNames (builtins.getFlake \"$flake\").nixosConfigurations"
        )

        if [ -n "$onlyHost" ] && ! jq -e --arg h "$onlyHost" 'any(. == $h)' <<<"$allhosts" > /dev/null; then
          echo "xela-outdated: host '$onlyHost' not in flake (hosts: $(jq -r 'join(", ")' <<<"$allhosts"))" >&2
          exit 1
        fi

        # stage 1 - one nix eval per host keeps memory bounded (a full-fleet
        # eval OOMs small machines)
        if [ -n "$onlyHost" ]; then
          hosts=("$onlyHost")
        else
          mapfile -t hosts < <(jq -r '.[]' <<<"$allhosts")
        fi
        for h in "''${hosts[@]}"; do
          echo "evaluating $h..." >&2
          nix eval --impure --json --expr "import ${./derived.nix} { dir = \"$flake\"; host = \"$h\"; }" \
            > "$tmp/derived-$h.json" \
            || {
              echo "xela-outdated: failed to evaluate $h" >&2
              exit 1
            }
        done

        jq -s '{ system: .[0].system, hosts: map(.host), entries: ([ .[] | .host as $h | .derived[] | . + { host: $h } ]) }' \
          "$tmp"/derived-*.json > "$tmp/merged.json"

        # stage 2 - four version columns for every tracked attr
        data=$(
          nix eval --impure --json --expr "import ${./outdated.nix} { dir = \"$flake\"; data = \"$tmp/merged.json\"; }"
        )

        total=$(jq '.packages | length' <<<"$data")
        nout=$(jq '[.packages[] | select(.outdated)] | length' <<<"$data")

        if [ "$nout" -eq 0 ] && [ "$showAll" = false ]; then
          echo "all $total tracked packages up to date"
          exit 0
        fi

        echo "our locked revs vs upstream channel tips ($nout of $total outdated)"
        echo

        jq -r --arg all "$showAll" '
          def vs($v): if $v == null then "n/a" else $v end;
          (if $all == "true" then .packages else [ .packages[] | select(.outdated) ] end)
          | (["PACKAGE", "OURS", "TIP", "LIVE"]),
            (.[]
              | [
                  (if .branch == "unstable" then .name + " ~"
                   elif $all == "true" and .outdated then .name + " *"
                   else .name end),
                  vs(.ours),
                  vs(.tip),
                  (.live | sort | join(" "))
                ])
          | @tsv
        ' <<<"$data" | gawk -F'\t' '
          { for (i = 1; i <= NF; i++) if (length($i) > w[i]) w[i] = length($i); lines[NR] = $0 }
          END {
            for (r = 1; r <= NR; r++) {
              n = split(lines[r], f, "\t")
              s = ""
              for (i = 1; i <= n; i++)
                s = s f[i] (i < n ? substr("                                ", 1, w[i] - length(f[i]) + 2) : "")
              print s
            }
          }'
      '';
    }
  ) { };
}
