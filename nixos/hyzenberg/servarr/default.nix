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
            inherit (svc) port;
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
      nginx.proxy.${svc.domain} = {
        target.port = svc.port;
        allowedServiceHosts = [
          "prowlarr"
          "radarr"
          "sonarr"
        ];
      };
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
  (mkServarr "prowlarr")
  (mkServarr "sonarr")
  (mkServarr "radarr")
]
