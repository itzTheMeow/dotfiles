{ config, lib, ... }:
let
  app = config.apps.copyparty;

  adminAccount = "admin";
  baseVolumeDir = "/var/lib/copyparty/volumes";

  mkVolume = name: opts: {
    "/${name}" = lib.recursiveUpdate {
      path = "${baseVolumeDir}/${name}";
      access = {
        wG = "*"; # write/upget for everyone
        A = adminAccount; # admin for admin
      };
      flags = {
        fk = "8"; # 8-character filekeys
        nosub = true; # no uploading into subfolders
        e2d = true; # per-volume upload db
      };
    } opts;
  };
  mkDropVolume =
    {
      # max size of files in `maxUnit` units
      maxSize,
      # file size unit for maxSize
      maxUnit,
      # max expiry time for files
      expiry,
      # max amount of uploaded files per `expiry` window
      maxUploads,
    }:
    mkVolume "drop-${toString maxSize}${maxUnit}" {
      flags = {
        # 1 byte to max size per file
        sz = "1-${toString maxSize}${maxUnit}";
        # delete uploads after expiry time
        lifetime = expiry;
        # max X uploads per IP per Y window
        maxn = "${toString maxUploads},${toString expiry}";
        # max X total upload volume per IP per Y window (max size * max uploads)
        maxb = "${toString (maxSize * maxUploads)}${maxUnit},${toString expiry}";
      };
    };
in
{
  apps.copyparty = {
    domain = "share.xela.codes";
    port = 21379;
    enableProxy = true;
    enableDNS = true;

    description = "File Sharing";
  };

  services.copyparty = {
    enable = true;
    settings = {
      i = app.ip;
      p = app.port;
      rproxy = -1; # trust closest reverse proxy
      xff-src = "100.64.0.0/16"; # trust tailscale proxy
      og-ua = "(Discord|Twitter|Slack)bot"; # do opengraph for these user-agents only

      # looks
      ui-nocpla = true; # hide "connect" button

      # hardening
      sss = true; # default safety
      nid = true; # hide disk usage
      df = 10; # stop uploads <10gb free space
      ban-pw = "9,3600,86400"; # ban an IP for 24h after 9 bad password attempts in 1h
      ah-salt = "rGZhRXBn1W4DUaO+OIXvTB1A"; # salt for hashing, no way to get this from a sops secret iirc
      ah-alg = "argon2"; # password hashing

      # performance
      e2dsa = true; # file indexing
      dedup = true; # file deduplication
      safe-dedup = 1; # make deduplication faster
    };
    # needs generated on the same machine to match hash
    accounts.${adminAccount}.passwordFile = config.sops.groupPaths.copyparty.admin-password;
    volumes =
      (mkDropVolume {
        maxSize = 5;
        maxUnit = "g";
        expiry = 15 * 60; # 15min
        maxUploads = 2;
      })
      // (mkDropVolume {
        maxSize = 1;
        maxUnit = "g";
        expiry = 12 * 60 * 60; # 12hr
        maxUploads = 5;
      })
      // (mkDropVolume {
        maxSize = 200;
        maxUnit = "m";
        expiry = 7 * 24 * 60 * 60; # 7d
        maxUploads = 50;
      });
  };
  systemd.services.copyparty.after = [ "tailscale-online.service" ];

  sops.groups.copyparty.admin-password = {
    value = "op://Private/whr3dgxxwzhxi6axd45fzta3km/Password Hash";
    owner = config.services.copyparty.user;
  };
}
