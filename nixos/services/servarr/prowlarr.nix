{ xelib, ... }:
let
  svc = xelib.services.prowlarr;
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
        bindaddress = xelib.hosts.${svc.host}.ip;
        port = svc.port;
        urlbase = "/prowlarr";
      };
    };
  };
  systemd.services.prowlarr.after = [ "tailscale-online.service" ];

  services.nginx.virtualHosts = proxyConfig.services.nginx.virtualHosts;
  security.acme.certs = proxyConfig.security.acme.certs;
}
