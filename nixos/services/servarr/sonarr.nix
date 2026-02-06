{
  host,
  lib,
  xelib,
  ...
}:
let
  svc = xelib.services.sonarr;
  bindaddress = xelib.hosts.${svc.host}.ip;
in
lib.mkMerge [
  {
    services.sonarr = {
      enable = true;
      settings = {
        app = {
          instancename = "Sonarr";
          theme = "dark";
        };
        server = {
          inherit bindaddress;
          port = svc.port;
          urlbase = "/";
        };
      };
    };
    systemd.services = lib.mkMerge [
      {
        sonarr.after = [ "tailscale-online.service" ];
      }
      # we need to mount tv shows
      (xelib.mkRcloneMount {
        config = "/home/${host.username}/.config/rclone/rclone.conf";
        name = "tv";
        remote = "pcloud:/Media/TVShows";
        mountPoint = "/mnt/tv";
        extraArgs = [
          "--allow-other"
          "--dir-perms=0777"
          "--file-perms=0666"
        ];
      })
    ];
  }
  (xelib.mkNginxProxy "sonarr.xela" "http://${xelib.hosts.${svc.host}.ip}:${toString svc.port}" { })
]
