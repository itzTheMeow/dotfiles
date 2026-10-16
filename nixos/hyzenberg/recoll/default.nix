{
  config,
  host,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  app = config.apps.recoll;
  tmpDir = "/var/lib/downloads-archive";
  mountPoint = "/mnt/rustic-downloads";
  indexDir = "/var/lib/recoll";
  confDir = "/etc/recoll";
  mountUnit = "rustic-mount-downloads.service";
  indexUnit = "recoll-index.service";

  # env exports mirroring _features/rustic so rustic/rclone/ntfy work off
  # of the user config
  home = "/home/${host.username}";
  serviceEnv = [
    "HOME=${home}"
    "PATH=${home}/.nix-profile/bin:${
      lib.makeBinPath [
        pkgs.rclone
        pkgs.rustic
        pkgs.fuse3
      ]
    }:/run/current-system/sw/bin"
    "RCLONE_CONFIG=${home}/.config/rclone/rclone.conf"
    "NTFY_CONFIG=${home}/.config/ntfy/client.yml"
    "NTFY_TAGS=${hostname}"
    "RECOLL_CONFDIR=${confDir}"
  ];

  # recoll shells out to these for text extraction; the rcl*.* uncompress
  # handlers (bare .gz/.xz/.bz2/.zst files) need their decompressors, which
  # recoll-nox does not ship
  helpersPath = lib.makeBinPath [
    pkgs.unzip
    pkgs.p7zip
    pkgs.unar
    pkgs.xz
    pkgs.gzip
    pkgs.bzip2
    pkgs.zstd
    pkgs.catdoc
    pkgs.antiword
    pkgs.unrtf
    pkgs.odt2txt
    pkgs.poppler-utils
    pkgs.exiftool
  ];

  unmount = pkgs.writeShellScript "rustic-downloads-unmount" ''
    if mountpoint -q "${mountPoint}"; then
      fusermount3 -uz "${mountPoint}" || umount -l "${mountPoint}" || true
    fi
    exit 0
  '';

  # monthly archive flow:
  #   1. move this month's files off pcloud into the staging dir (race-safe:
  #      rclone lists the source once at start, so files added mid-run stay
  #      on pcloud for next month; the Downloads dir itself is never
  #      removed, only its contents are moved)
  #   2. snapshot the staging dir into the rustic repo (as-path "/")
  #   3. verify the repo
  #   4. clear the staging dir (the files live in the repo now)
  #   5. mount the repo, re-index with recoll, unmount
  monthlyScript = pkgs.writeShellScript "downloads-archive" ''
    set -euo pipefail
    export ${lib.concatStringsSep " " serviceEnv}

    # ntfy notification on any failure (recoll-index/rclone/rustic included);
    # set -e auto-exits after the trap runs, keeping the failure rc
    _fail() {
      local rc=$?
      ${pkgs.ntfy-sh}/bin/ntfy publish \
        -t "Archive failed (downloads)" \
        "downloads-archive.service failed (rc $rc): $BASH_COMMAND"
    }
    trap _fail ERR

    # the mount must not hold a repo lock while backing up; also clear a
    # stale mount left by a crashed run (inactive unit's ExecStopPost
    # doesn't run, but the fuse endpoint can linger and break topdirs)
    systemctl stop "${mountUnit}" || true
    ${unmount}

    rclone move "pcloud:Downloads" "${tmpDir}" --exclude .directory
    # rclone's move prunes nothing: empty dirs pile up on pcloud. rmdirs
    # only removes truly empty ones, so dirs that gained late files stay
    rclone rmdirs "pcloud:Downloads" --leave-root || true

    # nothing to archive this month
    if [ -z "$(ls -A "${tmpDir}")" ]; then
      echo "nothing in Downloads to archive" >&2
      exit 0
    fi

    rustic -P downloads backup "${tmpDir}"
    rustic -P downloads check

    # files live in the repo now; nuke the staging dir wholesale (systemd
    # StateDirectory recreates it on the next start)
    rm -rf -- "${tmpDir}"

    # bring the mount up so recoll sees the new snapshot, re-index, unmount
    systemctl start "${mountUnit}"
    timeout=60
    while ! mountpoint -q "${mountPoint}"; do
      timeout=$((timeout - 1))
      if [ "$timeout" -le 0 ]; then
        echo "rustic mount did not come up" >&2
        exit 1
      fi
      sleep 1
    done

    echo "indexing..."

    systemctl start "${indexUnit}"

    echo "done."

    systemctl stop "${mountUnit}"

    ${pkgs.ntfy-sh}/bin/ntfy publish -t "Archive Indexed (downloads)" \
      "Recoll index updated with the latest Downloads snapshot"
  '';
in
{
  apps.recoll = {
    domain = "recoll.xela";
    port = 21987;
    enableProxy = true;

    name = "Recoll";
    description = "File Archive Search";
    icon = "https://www.recoll.org/pics/recoll64.png";
  };

  # gate the search index behind pocket-id; snippets reveal file contents
  #nginx.proxy."recoll.xela".oidcGroups = [ "recoll" ];

  # dbdir (not indexdir): the xapian db location, else it lands next to the
  # conf files
  environment.etc."recoll/recoll.conf".text = ''
    topdirs = ${mountPoint}
    dbdir = ${indexDir}
    skippedPaths = ${mountPoint}/latest
  '';

  # mimeconf/mimemap are ConfStacks: entries merge per-key with the shipped
  # defaults. recoll disables tar member indexing by default (zip is active),
  # and maps .tar.xz/.txz through the uncompress roundtrip instead of
  # rcltar's native xz support. .ntb are Notability notes (zip archives
  # with noteBundle + hashed assets).
  environment.etc."recoll/mimeconf".text = ''
    [index]
    application/x-tar = execm rcltar.py
  '';

  environment.etc."recoll/mimemap".text = ''
    .tar.xz = application/x-tar
    .txz = application/x-tar
    .ntb = application/zip
  '';

  systemd.tmpfiles.rules = [
    "d ${indexDir} 0755 root root -"
  ];

  # mounts the whole repo as /<snapshot-id>/ dirs; only alive while
  # (re)indexing - start it manually for ad-hoc browsing
  systemd.services.rustic-mount-downloads = {
    description = "Rustic downloads repo mount";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      Environment = serviceEnv;
      ExecStartPre = [
        # clear a stale/broken mount from a previous crashed run, else the
        # new fuse mount comes up at "transport endpoint not connected"
        ''
          ${unmount}
          ${pkgs.coreutils}/bin/mkdir -p ${mountPoint}
        ''
      ];
      ExecStart = "${pkgs.rustic}/bin/rustic -P downloads mount";
      ExecStopPost = "${unmount}";
    };
  };

  # incremental index update; the first run indexes everything
  systemd.services.recoll-index = {
    description = "Recoll index update";
    serviceConfig = {
      Type = "oneshot";
      # indexing the full archive can take hours
      TimeoutStartSec = 0;
      Environment = [
        "RECOLL_CONFDIR=${confDir}"
        "PATH=${helpersPath}:/run/current-system/sw/bin"
      ];
      ExecStart = "${pkgs.recoll-nox}/bin/recollindex";
    };
  };

  systemd.services.downloads-archive = {
    description = "Archive pcloud Downloads into rustic and re-index";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = config.environment.sessionVariables;
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "downloads-archive";
      # moving + uploading a month of files can take a long time
      TimeoutStartSec = 0;
      Environment = serviceEnv;
      ExecStart = monthlyScript;
      ExecStopPost = "${unmount}";
    };
  };

  systemd.timers.downloads-archive = {
    description = "Monthly pcloud Downloads archive timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-01 05:00:00";
      Persistent = true;
    };
  };

  systemd.services.recoll-webui = {
    description = "Recoll WebUI";
    after = [ "tailscale-online.service" ];
    wantedBy = [ "multi-user.target" ];
    environment.RECOLL_CONFDIR = confDir;
    serviceConfig = {
      User = "recoll-webui";
      Group = "recoll-webui";
      ExecStart = "${pkgs.recoll-webui}/bin/recollwebui -a ${app.ip} -p ${app.portString} -c ${confDir}";
      Restart = "on-failure";
    };
  };

  users.users.recoll-webui = {
    isSystemUser = true;
    group = "recoll-webui";
  };
  users.groups.recoll-webui = { };
}
