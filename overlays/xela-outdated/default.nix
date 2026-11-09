final: prev: {
  xela-outdated = final.callPackage (
    {
      coreutils,
      curl,
      gawk,
      jq,
      nix,
      writeShellApplication,
    }:
    writeShellApplication {
      name = "xela-outdated";
      runtimeInputs = [
        coreutils
        curl
        gawk
        jq
        nix
      ];
      text = ''
        set -euo pipefail

        usage() {
          cat <<'EOF'
        usage: xela-outdated [--host HOST] [--all] [--upgrade]

        check directly-used packages against the upstream nixpkgs channels.
        locked revisions come from flake.lock; tips from channels.nixos.org.
        with --upgrade, NEXT also shows the next nixpkgs release branch tip
        (what a release jump brings); until that branch is cut it falls back
        to the unstable tip (unstable pins show n/a there - their TIP already
        is that value).

          --host HOST   only include HOST (default: every host in the flake)
          --all         also show up-to-date and unmapped packages
          --upgrade     also fetch and show the NEXT column
          -h, --help    show this help
        EOF
        }

        flake="''${DOTFILES:-$PWD}"
        onlyHost=""
        showAll=false
        showNext=false

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
            --upgrade)
              showNext=true
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

        # refs the columns are anchored to
        stable_ref=$(jq -r '.nodes[.root].inputs.nixpkgs as $k | .nodes[$k].original.ref // empty' "$flake/flake.lock")
        unstable_ref=$(jq -r '.nodes[.root].inputs."nixpkgs-unstable" as $k | .nodes[$k].original.ref // empty' "$flake/flake.lock")

        # date (MM/DD) anchors for the column headers - OURS from the locked
        # input's lastModified, TIP from the upstream tip's commit date (one
        # unauthenticated GitHub API call per ref; the header omits the date
        # when a lookup fails)
        tipDate() {
          local ref="$1" d
          d=$(curl -fsL --max-time 20 "https://api.github.com/repos/NixOS/nixpkgs/commits/$ref" \
            2>/dev/null | jq -r '.commit.committer.date // empty' 2>/dev/null) || d=""
          if [ -n "$d" ]; then
            date -d "$d" +%m/%d 2>/dev/null || echo ""
          else
            echo ""
          fi
        }
        lockedEpoch=$(jq -r '.nodes[.root].inputs.nixpkgs as $k | .nodes[$k].locked.lastModified // empty' "$flake/flake.lock")
        oursDate=""
        stableDate=""
        if [ -n "$lockedEpoch" ]; then
          oursDate=$(date -d "@''$lockedEpoch" +%m/%d 2>/dev/null) || oursDate=""
        fi
        if [ -n "$stable_ref" ]; then
          stableDate=$(tipDate "$stable_ref")
        fi

        # the tip that ALL stable/unstable packages would move to on a release
        # jump - the next release branch when it exists, else the latest
        # unstable tip (what the branch will be cut from). only resolved with
        # --upgrade, since nothing else consumes it.
        nextArg=""
        nextSource=""
        if [ "$showNext" = "true" ]; then
          case "$stable_ref" in
            nixos-*.05) next="''${stable_ref%.05}.11" ;;
            nixos-*.11)
              yy=''${stable_ref#nixos-}
              yy=''${yy%.11}
              next="nixos-$(printf '%02d' $((10#$yy + 1))).05"
              ;;
            *) next="" ;;
          esac
          if [ -n "$next" ] && curl -fsIL --max-time 20 -o /dev/null "https://github.com/NixOS/nixpkgs/archive/$next.tar.gz"; then
            nextSource="branch"
            nextArg="; nextSrc = \"https://github.com/NixOS/nixpkgs/archive/$next.tar.gz\""
          else
            nextSource="''${unstable_ref:-unstable}"
            nextArg="; nextSrc = \"unstable\""
          fi
        fi

        # stage 2 - version columns (+ NEXT with --upgrade) for every tracked attr
        data=$(
          nix eval --impure --json --expr "import ${./outdated.nix} { dir = \"$flake\"; data = \"$tmp/merged.json\"$nextArg; }"
        )

        total=$(jq '.packages | length' <<<"$data")
        nout=$(jq '[.packages[] | select(.outdated or .nextChanged)] | length' <<<"$data")

        if [ "$nout" -eq 0 ] && [ "$showAll" = false ]; then
          echo "all $total tracked packages up to date"
          exit 0
        fi

        # column headers stating the rev/date they mean: OURS against the
        # locked stable rev, TIP against the upstream tip, NEXT (with
        # --upgrade) against the next release branch or unstable
        ourRev="''${stable_ref#nixos-}"
        if [ -n "$oursDate" ]; then
          oursH="OURS (''$ourRev ''$oursDate)"
        else
          oursH="OURS (''$ourRev)"
        fi
        if [ -n "$stableDate" ]; then
          tipH="TIP (''$stableDate)"
        else
          tipH="TIP"
        fi
        nextH=""

        echo "our locked revs vs upstream channel tips ($nout of $total change)"
        markers="~ = unstable pin"
        if [ "$showNext" = "true" ]; then
          markers="$markers  + = newer in NEXT"
        fi
        echo "symbols: $markers"
        if [ "$showNext" = "true" ]; then
          if [ "$nextSource" = "branch" ]; then
            nextRef=$(jq -r '.nextRef' <<<"$data")
            echo "NEXT = $nextRef branch tip"
            nextH="NEXT ($nextRef)"
          else
            echo "NEXT = $nextSource tip (next release branch not cut yet; unstable pins show n/a)"
            nextH="NEXT ($nextSource)"
          fi
        fi
        echo

        jq -r --arg all "$showAll" --arg showNext "$showNext" \
          --arg oursH "$oursH" --arg tipH "$tipH" --arg nextH "$nextH" \
          '
          def vs($v): if $v == null then "n/a" else $v end;
          def row($next):
            ((if .branch == "unstable" then .name + " ~" else .name end)
             + (if .nextChanged then " +" else "" end)) as $n
            | if $next then
                [ $n, vs(.ours), vs(.tip), vs(.next), (.live | sort | join(" ")) ]
              else
                [ $n, vs(.ours), vs(.tip), (.live | sort | join(" ")) ]
              end;
          (if $all == "true" then .packages
           else [ .packages[] | select(.outdated or .nextChanged) ] end)
          | (if $showNext == "true" then [ "PACKAGE", $oursH, $tipH, $nextH, "LIVE" ]
             else [ "PACKAGE", $oursH, $tipH, "LIVE" ] end),
            (.[ ] | row($showNext == "true"))
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
