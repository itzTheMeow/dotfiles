{
  host,
  lib,
  xelib,
  ...
}:
let
  mkServarr =
    name:
    let
      svc = xelib.services.${name};
      bindaddress = xelib.hosts.${svc.host}.ip;
    in
    lib.mkMerge [
      {
        services.${name} = {
          enable = true;
          settings = {
            app = {
              instancename = xelib.toTitleCase name;
              theme = "dark";
            };
            server = {
              inherit bindaddress;
              port = svc.port;
              urlbase = "/";
            };
          };
        };
        systemd.services.${name}.after = [ "tailscale-online.service" ];
        systemd.services.${name}.serviceConfig.SupplementaryGroups = [ "nzbget" ];
      }
      (xelib.mkNginxProxy svc.domain "http://${bindaddress}:${toString svc.port}" { })
    ];
in
lib.mkMerge [
  {
    # mount the shared backup directory
    systemd.services = xelib.mkRcloneMount {
      config = "/home/${host.username}/.config/rclone/rclone.conf";
      name = "servarr-backups";
      remote = "pcloud:/Misc/Backups/Servarr";
      mountPoint = "/mnt/servarr_backups";
      extraArgs = [
        "--allow-other"
        "--dir-perms=0777"
        "--file-perms=0666"
      ];
    };
  }
  (mkServarr "prowlarr")
  (mkServarr "sonarr")
  (mkServarr "radarr")
]
