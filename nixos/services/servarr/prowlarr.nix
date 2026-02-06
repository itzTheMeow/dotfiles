{ xelib, ... }:
let
  svc = xelib.services.prowlarr;
  bindaddress = xelib.hosts.${svc.host}.ip;

  proxyConfig =
    xelib.mkNginxProxy "prowlarr.xela" "http://${xelib.hosts.${svc.host}.ip}:${toString svc.port}"
      { };
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
        urlbase = "/";
      };
    };
  };
  systemd.services.prowlarr.after = [ "tailscale-online.service" ];

  security.acme.certs = proxyConfig.security.acme.certs;
  services.nginx.virtualHosts = proxyConfig.services.nginx.virtualHosts;
}
# include the host settings for the domain
#// xelib.mkNginxProxy "prowlarr.xela" "http://${bindaddress}:${toString svc.port}" { }
