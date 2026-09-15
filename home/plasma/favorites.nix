# Declarative kickoff "Application Launcher" favorites (pinned set + order).
#
# plasma-manager has no favorites option upstream (nix-community/plasma-manager#376/#539),
# so we reconcile them imperatively once per login:
#   * the pinned set lives in kactivitymanagerd's SQLite database
#     (~/.local/share/kactivitymanagerd/resources/database, `ResourceLink` table);
#   * the displayed order lives in kactivitymanagerd-statsrc under
#     `Favorites-org.kde.plasma.kickoff.favorites.instance-<id>-{global,<activity>}`.
# Instance ids change on every panel rebuild, and the kickoff model falls back to the
# highest existing ordering group when its own is missing, which made the order drift.
# We write the same ordering to every instance group so the fallback is deterministic,
# add/remove the kactivitymanagerd links via its D-Bus API, then restart plasmashell
# only when something actually changed.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.plasma;

  # manage only when plasma is enabled and a favorites list is declared
  manages = cfg.enable && cfg.launcherFavorites != [ ];

  favoritesCsv = lib.concatStringsSep "," cfg.launcherFavorites;

  qdbus = lib.getExe' pkgs.kdePackages.qttools "qdbus";
  sqlite3 = lib.getExe' pkgs.sqlite "sqlite3";
  systemctl = lib.getExe' pkgs.systemd "systemctl";

  syncScript = pkgs.writeShellScript "plasma-kickoff-favorites-sync" ''
    set -euo pipefail

    agent="org.kde.plasma.favorites.applications"
    service="org.kde.ActivityManager"
    object="/ActivityManager/Resources/Linking"
    iface="org.kde.ActivityManager.ResourcesLinking"
    db="${config.xdg.dataHome}/kactivitymanagerd/resources/database"
    appletsrc="${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc"
    statsrc="${config.xdg.configHome}/kactivitymanagerd-statsrc"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    declared="$tmp/declared"
    existing="$tmp/existing"
    groups="$tmp/groups"

    favorites_csv='${favoritesCsv}'

    # declared set, one resource per line (no commas in entries)
    printf '%s' "$favorites_csv" | tr ',' '\n' > "$declared"

    changed=0

    # --- pinned set: reconcile links with the kactivitymanagerd database ---
    if [ -f "$db" ]; then
      "${sqlite3}" -readonly "$db" "SELECT targettedResource FROM ResourceLink WHERE initiatingAgent = '$agent';" > "$existing" 2>/dev/null || : > "$existing"
    else
      : > "$existing"
    fi

    need_link=0
    need_unlink=0
    while IFS= read -r res; do
      grep -Fqx "$res" "$existing" || need_link=1
    done < "$declared"
    while IFS= read -r res; do
      grep -Fqx "$res" "$declared" || need_unlink=1
    done < "$existing"

    if [ "$need_link" -eq 1 ] || [ "$need_unlink" -eq 1 ]; then
      # wait (bounded) for the ActivityManager session service to come up
      i=0
      until "${qdbus}" "$service" "$object" >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -ge 120 ] && break
        sleep 0.5
      done
      if "${qdbus}" "$service" "$object" >/dev/null 2>&1; then
        while IFS= read -r res; do
          grep -Fqx "$res" "$existing" || {
            "${qdbus}" "$service" "$object" "$iface.LinkResourceToActivity" "$agent" "$res" ":global"
            changed=1
          }
        done < "$declared"
        while IFS= read -r res; do
          grep -Fqx "$res" "$declared" || {
            "${qdbus}" "$service" "$object" "$iface.UnlinkResourceFromActivity" "$agent" "$res" ":global"
            changed=1
          }
        done < "$existing"
      else
        echo "kactivitymanagerd D-Bus not available; skipping favorites link reconcile." >&2
      fi
    fi

    # --- ordering: same declared order in every kickoff instance group ---
    {
      # groups that already exist in the stats config
      grep -o '^\[Favorites-org.kde.plasma.kickoff.favorites.instance-[^]]*\]' "$statsrc" 2>/dev/null | tr -d '[]' || true
      # groups for the currently active instances (ids from the panel layout)
      awk '
        /^\[[^]]*\]\[[^]]*\]\[Applets\]\[[0-9]+\]$/ {
          s = $0
          sub(/.*\[Applets\]\[/, "", s)
          sub(/\]$/, "", s)
          id = s
        }
        /^plugin=org.kde.plasma.kickoff$/ {
          print "Favorites-org.kde.plasma.kickoff.favorites.instance-" id "-global"
        }
      ' "$appletsrc" 2>/dev/null || true
    } | sort -u > "$groups"

    # kwriteconfig6 uses atomic writes (temp+rename) which fail with
    # EBUSY while kactivitymanagerd holds the lock. Rewrite in-place
    # via awk instead.
    if [ -f "$statsrc" ]; then
      awk -v csv="$favorites_csv" '
        /^\[Favorites-org.kde.plasma.kickoff.favorites.instance-/ { in_kf = 1; print; next }
        /^\[/ { in_kf = 0 }
        in_kf && /^ordering=/ { print "ordering=" csv; next }
        { print }
      ' "$statsrc" > "$tmp/statsrc_new"
    else
      : > "$tmp/statsrc_new"
    fi
    # add groups for active instances that don't exist in the file yet
    while IFS= read -r g; do
      grep -q "^\[$g\]$" "$tmp/statsrc_new" || printf '\n[%s]\nordering=%s\n' "$g" "$favorites_csv" >> "$tmp/statsrc_new"
    done < "$groups"
    if ! diff -q "$statsrc" "$tmp/statsrc_new" >/dev/null 2>&1; then
      cp "$tmp/statsrc_new" "$statsrc"
      changed=1
    fi

    # --- apply: restart plasmashell so kickoff reloads links + ordering ---
    if [ "$changed" -eq 1 ]; then
      "${systemctl}" --user restart plasma-plasmashell
    fi
  '';
in
{
  options.programs.plasma.launcherFavorites = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [
      "applications:org.kde.dolphin.desktop"
      "preferred://browser"
    ];
    description = ''
      Applications pinned to the Application Launcher (kickoff), as
      `applications:<menu-id>.desktop` / `preferred://<scheme>` resource strings.
      The set is reconciled with kactivitymanagerd and the order is written to
      every kickoff instance group, so both survive reboots and panel rebuilds.
    '';
    apply = lib.unique;
  };

  config = lib.mkIf manages {
    programs.plasma.startup.desktopScript.favorites = {
      # after the panel desktop script (priority 2) rebuilt the appletsrc
      priority = 3;
      # run at every login: the config files are not managed by plasma-manager
      runAlways = true;
      text = "";
      # the actual work runs as a plain shell script (see syncScript above)
      postCommands = toString syncScript;
    };
  };
}
