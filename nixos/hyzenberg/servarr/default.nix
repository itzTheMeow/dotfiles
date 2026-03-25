{
  config,
  host,
  lib,
  xelib,
  ...
}:
let
  mkServarr =
    name: port:
    let
      app = config.apps.${name};
    in
    {
      apps.${name} = {
        domain = "${name}.xela";
        inherit port;
        enableProxy = true;
      };

      services.${name} = {
        enable = true;
        settings = {
          app = {
            instancename = xelib.toTitleCase name;
            theme = "dark";
          };
          server = {
            bindaddress = app.ip;
            inherit (app) port;
            urlbase = "/";
          };
        };
      };
      systemd.services.${name} = {
        after = [ "tailscale-online.service" ];
        serviceConfig.SupplementaryGroups = [
          "mediacenter"
          "nzbget"
        ];
      };

      # the servarr programs can talk to eachother
      nginx.proxy.${app.domain}.allowedAppHosts = [
        "prowlarr"
        "radarr"
        "sonarr"
      ];
    };
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
    systemd.tmpfiles.rules = [
      "d /mnt/servarr_backups 0755 ${host.username} users -"
    ];
  }
  (mkServarr "prowlarr" 49696)
  (mkServarr "sonarr" 48989)
  (mkServarr "radarr" 47878)
]
