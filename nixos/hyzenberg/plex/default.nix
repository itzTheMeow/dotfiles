{
  config,
  lib,
  xelib,
  ...
}:
let
  app = config.apps.plex;
  pub = xelib.dns.splitDomain app.details.publicDomain;
in
{
  imports = [ ./tautulli.nix ];

  apps.plex = {
    domain = "plex.xela";
    port = 32400;
    enableProxy = true;
    details = {
      publicDomain = "plex.${xelib.domain}";
    };

    description = "Media Server";
  };

  # fsr plex doesnt let you change the bind address/port...
  services.plex.enable = true;
  systemd.services.plex = {
    after = [ "tailscale-online.service" ];
    serviceConfig = {
      SupplementaryGroups = [ "mediacenter" ];

      # allow access to home
      ProtectHome = lib.mkForce "read-only";
      # bind paths that should be accessible
      BindReadOnlyPaths = [
        "/home/meow"
        "/mnt/tv"
        "/mnt/movies"
      ];
    };
  };

  # set up public domain too
  nginx.proxy.${app.details.publicDomain}.target = {
    host = app.ip;
    port = app.port;
  };
  dnszones.list."${pub.domain}".subdomains."${pub.subdomain}" = xelib.dns.pointHost app.host;
}
