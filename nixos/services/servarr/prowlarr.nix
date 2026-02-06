{ xelib, ... }:
let
  svc = xelib.services.prowlarr;
  bindaddress = xelib.hosts.${svc.host}.ip;
in
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
      };
    };
  };
  systemd.services.prowlarr.after = [ "tailscale-online.service" ];
}
# include the host settings for the domain
// xelib.mkNginxProxy "prowlarr.xela" "http://${bindaddress}:${toString svc.port}" { }
