# Declarative Kickoff (Application Launcher) favorites.
#
# Upstream context (plasma-manager has no favorites option, nix-community/plasma-manager#376,
# #539, discussion #506; PR #238 dropped it as too tricky, PR #642 was closed by its author):
# the pinned set lives in kactivitymanagerd's SQLite database
# (~/.local/share/kactivitymanagerd/resources/database, `ResourceLink` table) and the displayed
# order lives in kactivitymanagerd-statsrc under
# `Favorites-org.kde.plasma.kickoff.favorites.instance-<id>-{global,<activity>}` groups.
# Neither is writable declaratively:
#   * the ordering groups' instance ids are assigned by Plasma at runtime and change on every
#     panel rebuild;
#   * kactivitymanagerd and plasmashell both read statsrc at startup and never re-read it —
#     kactivitymanagerd flushes its stale in-memory copy back at logout, so anything written
#     post-login diverges again before the next boot (which made the old approach restart
#     plasmashell at every login).
# We therefore reconcile both *before* the workspace starts: a oneshot user unit ordered
# before plasma-kactivitymanagerd.service and plasma-plasmashell.service rewrites the
# ordering in-place (kwriteconfig6 would fail with EBUSY later, but nothing holds the file
# yet) and writes the ResourceLink rows directly. Nothing needs to be restarted — the first
# plasmashell of the session already reads the correct state.
# A run-once startup script only handles the fresh-profile edge case where the database
# didn't exist pre-login: it links the favorites through kactivitymanagerd's D-Bus API
# (which creates the database) and restarts plasmashell just for that first session.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.plasma;

  # manage only when plasma is enabled and a favorites list is declared
  manages = cfg.enable && cfg.kickoff.favorites != null;

  favoritesCsv = lib.concatStringsSep "," (lib.unique cfg.kickoff.favorites);

  qdbus = lib.getExe' pkgs.kdePackages.qttools "qdbus";
  sqlite3 = lib.getExe' pkgs.sqlite "sqlite3";
  systemctl = lib.getExe' pkgs.systemd "systemctl";

  agent = "org.kde.plasma.favorites.applications";
  activity = ":global";
  service = "org.kde.ActivityManager";
  object = "/ActivityManager/Resources/Linking";
  iface = "org.kde.ActivityManager.ResourcesLinking";
  # double-quoted so the literal `''` doesn't terminate the indented shell string
  sqEscape = "s/'/''/g";

  # Reconcile the pinned set and ordering *before* anything has read them.
  syncScript = pkgs.writeShellScript "plasma-kickoff-favorites-sync" ''
    set -euo pipefail

    db="${config.xdg.dataHome}/kactivitymanagerd/resources/database"
    appletsrc="${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc"
    statsrc="${config.xdg.configHome}/kactivitymanagerd-statsrc"

    favorites_csv='${favoritesCsv}'

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    printf '%s\n' "$favorites_csv" | tr ',' '\n' > "$tmp/declared"

    # --- pinned set: reconcile ResourceLink rows directly in the database ---
    # (kactivitymanagerd is not running yet, so nothing holds the database)
    if [ -f "$db" ]; then
      "${sqlite3}" -readonly "$db" \
        "SELECT targettedResource FROM ResourceLink WHERE initiatingAgent = '${agent}' AND usedActivity = '${activity}';" \
        > "$tmp/existing" 2>/dev/null || : > "$tmp/existing"
      {
        echo "BEGIN TRANSACTION;"
        while IFS= read -r res; do
          [ -n "$res" ] || continue
          grep -Fqx "$res" "$tmp/declared" || printf \
            "DELETE FROM ResourceLink WHERE usedActivity = '${activity}' AND initiatingAgent = '${agent}' AND targettedResource = '%s';\n" \
            "$(printf '%s' "$res" | sed "${sqEscape}")"
        done < "$tmp/existing"
        while IFS= read -r res; do
          [ -n "$res" ] || continue
          grep -Fqx "$res" "$tmp/existing" || printf \
            "INSERT OR IGNORE INTO ResourceLink (usedActivity, initiatingAgent, targettedResource) VALUES ('${activity}', '${agent}', '%s');\n" \
            "$(printf '%s' "$res" | sed "${sqEscape}")"
        done < "$tmp/declared"
        echo "COMMIT;"
      } | "${sqlite3}" "$db" >/dev/null
    fi

    # --- ordering: same declared order in every kickoff instance group ---
    # Active kickoff applet ids (one per line) from the panel layout.
    if [ -f "$appletsrc" ]; then
      awk '
        /^\[[^]]*\]\[[^]]*\]\[Applets\]\[[0-9]+\]$/ {
          s = $0
          sub(/.*\[Applets\]\[/, "", s)
          sub(/\]$/, "", s)
          id = s
        }
        /^plugin=org.kde.plasma.kickoff$/ { print id }
      ' "$appletsrc" | sort -u > "$tmp/ids"
    else
      : > "$tmp/ids"
    fi

    # Rewrite the ordering of every favorites group in place, dropping groups
    # whose instance id no longer exists in the panel layout. Pruning is
    # skipped when the layout is unreadable, so a fresh profile keeps nothing
    # but doesn't destroy anything either.
    # The ids are read via getline in BEGIN instead of the `FNR == NR`
    # two-file idiom: with an empty ids file that idiom treats every line of
    # statsrc as the first file, and statsrc would be truncated to nothing.
    if [ -f "$statsrc" ]; then
      awk -v csv="$favorites_csv" -v idsfile="$tmp/ids" \
        -v prune="$([ -s "$tmp/ids" ] || echo skip)" '
        BEGIN {
          printing = 1
          while ((getline line < idsfile) > 0) if (line != "") active[line] = 1
          close(idsfile)
        }
        /^\[Favorites-org\.kde\.plasma\.kickoff\.favorites\.instance-/ {
          group = $0
          id = group
          sub(/^\[Favorites-org\.kde\.plasma\.kickoff\.favorites\.instance-/, "", id)
          if (match(id, /^[0-9]+/)) id = substr(id, 1, RLENGTH); else id = ""
          keep = (prune == "skip") || (id in active)
          printing = keep
          if (keep) print group
          next
        }
        /^\[/ { printing = 1 }
        printing && /^ordering=/ { print "ordering=" csv; next }
        printing { print }
      ' "$statsrc" > "$tmp/statsrc_new"
    else
      : > "$tmp/statsrc_new"
    fi
    # add the global group for every active instance that doesn't have one yet
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      group="Favorites-org.kde.plasma.kickoff.favorites.instance-''${id}-global"
      grep -q "^\[''${group}\]$" "$tmp/statsrc_new" \
        || printf '\n[%s]\nordering=%s\n' "$group" "$favorites_csv" >> "$tmp/statsrc_new"
    done < "$tmp/ids"

    if [ -f "$statsrc" ] || [ -s "$tmp/statsrc_new" ]; then
      if ! cmp -s "$statsrc" "$tmp/statsrc_new"; then
        mkdir -p "$(dirname "$statsrc")"
        cp "$tmp/statsrc_new" "$statsrc"
      fi
    fi
  '';

  # Fresh-profile fallback: the database only exists once kactivitymanagerd
  # first ran, so the pre-login reconcile above can't have written the links.
  # Runs once (content-hash gated by plasma-manager) and only acts when the
  # links are still missing or stale.
  fallbackScript = pkgs.writeShellScript "plasma-kickoff-favorites-fallback" ''
    set -euo pipefail

    db="${config.xdg.dataHome}/kactivitymanagerd/resources/database"

    favorites_csv='${favoritesCsv}'

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    printf '%s\n' "$favorites_csv" | tr ',' '\n' > "$tmp/declared"

    if [ -f "$db" ]; then
      "${sqlite3}" -readonly "$db" \
        "SELECT targettedResource FROM ResourceLink WHERE initiatingAgent = '${agent}' AND usedActivity = '${activity}';" \
        > "$tmp/existing" 2>/dev/null || : > "$tmp/existing"
    else
      : > "$tmp/existing"
    fi

    need_change=0
    while IFS= read -r res; do
      [ -n "$res" ] || continue
      grep -Fqx "$res" "$tmp/existing" || need_change=1
    done < "$tmp/declared"
    while IFS= read -r res; do
      [ -n "$res" ] || continue
      grep -Fqx "$res" "$tmp/declared" || need_change=1
    done < "$tmp/existing"
    [ "$need_change" -eq 1 ] || exit 0

    # wait (bounded) for the ActivityManager session service to come up
    i=0
    until "${qdbus}" "${service}" "${object}" >/dev/null 2>&1; do
      i=$((i + 1))
      [ "$i" -ge 120 ] && break
      sleep 0.5
    done
    if "${qdbus}" "${service}" "${object}" >/dev/null 2>&1; then
      while IFS= read -r res; do
        [ -n "$res" ] || continue
        grep -Fqx "$res" "$tmp/existing" \
          || "${qdbus}" "${service}" "${object}" "${iface}.LinkResourceToActivity" "${agent}" "$res" "${activity}"
      done < "$tmp/declared"
      while IFS= read -r res; do
        [ -n "$res" ] || continue
        grep -Fqx "$res" "$tmp/declared" \
          || "${qdbus}" "${service}" "${object}" "${iface}.UnlinkResourceFromActivity" "${agent}" "$res" "${activity}"
      done < "$tmp/existing"
      # only reached on the rare session where the pre-login reconcile could
      # not write the database; plasmashell needs the reload for the links
      "${systemctl}" --user restart plasma-plasmashell
    else
      echo "kactivitymanagerd D-Bus not available; skipping favorites link reconcile." >&2
    fi
  '';
in
{
  options.programs.plasma.kickoff.favorites = lib.mkOption {
    type = with lib.types; nullOr (listOf str);
    default = null;
    example = [
      "applications:org.kde.dolphin.desktop"
      "preferred://browser"
    ];
    description = ''
      Applications pinned to the Application Launcher (kickoff), in order, as
      `applications:<menu-id>.desktop` / `preferred://<scheme>` resource strings.
      The set is reconciled with kactivitymanagerd and the order is written to
      every kickoff instance group before the workspace starts, so both survive
      reboots and panel rebuilds.
    '';
  };

  config = lib.mkIf manages {
    systemd.user.services.plasma-kickoff-favorites = {
      Unit = {
        Description = "Reconcile declarative Kickoff favorites before the Plasma workspace starts";
        # Must run before kactivitymanagerd (which reads the stats config and the
        # link database into memory and flushes them back at logout) and
        # plasmashell (which reads the ordering)
        After = [ "basic.target" ];
        Before = [
          "plasma-kactivitymanagerd.service"
          "plasma-plasmashell.service"
          "graphical-session.target"
        ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
      };
      Install = {
        WantedBy = [ "plasma-core.target" ];
      };
    };

    programs.plasma.startup.startupScript."kickoff_favorites" = {
      priority = 3;
      text = "${fallbackScript}";
    };
  };
}
