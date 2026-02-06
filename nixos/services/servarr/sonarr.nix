{
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
    systemd.services.sonarr.after = [ "tailscale-online.service" ];
  }
  (xelib.mkNginxProxy "sonarr.xela" "http://${xelib.hosts.${svc.host}.ip}:${toString svc.port}" { })
]
