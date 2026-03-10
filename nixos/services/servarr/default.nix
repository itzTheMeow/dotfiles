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
      }
      {
        systemd.services.${name}.serviceConfig.SupplementaryGroups = [ "nzbget" ];
      }
      (xelib.mkNginxProxy svc.domain "http://${bindaddress}:${toString svc.port}" {
        # the servarr programs can talk to eachother
        allowedHosts = xelib.mkServiceHosts [
          "prowlarr"
          "radarr"
          "sonarr"
        ];
      })
    ];
in
lib.mkMerge [
  {
    # mount the shared backup directory
    home-manager.users.${host.username}.programs.rclone.remotes.pcloud.mounts."/Misc/Backups/Servarr" =
      {
        enable = true;
        mountPoint = "/mnt/servarr_backups";
        options = {
          allow-other = true;
          dir-perms = "0777";
          file-perms = "0666";
        };
      };
  }
  (mkServarr "prowlarr")
  (mkServarr "sonarr")
  (mkServarr "radarr")
]
