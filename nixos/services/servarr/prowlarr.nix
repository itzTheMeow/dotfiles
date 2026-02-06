{ xelib, lib, ... }:
let
  svc = xelib.services.prowlarr;
  bindaddress = xelib.hosts.${svc.host}.ip;
in
lib.mkMerge [
  {
    services.prowlarr = {
      enable = true;
      settings = {
        app = {
          instancename = "Prowlarr";
          theme = "dark";
        };
        server = {
          inherit bindaddress;
          port = svc.port;
          urlbase = "/";
        };
      };
    };
    systemd.services.prowlarr.after = [ "tailscale-online.service" ];
  }
  (xelib.mkNginxProxy "prowlarr.xela" "http://${xelib.hosts.${svc.host}.ip}:${toString svc.port}" { })
]
