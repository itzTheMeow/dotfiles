{
  config,
  pkgs,
  xelib,
  ...
}:
let
  app = config.apps.immich;
  splitPublicDomain = xelib.dns.splitDomain app.details.publicDomain;

  # list of paths to be hosted publicly (shared links only)
  publicPaths = [
    # shared link routes (spa)
    "/s/"
    "/share/"
    "/_app"
    # static files
    "/favicon.ico"
    "/favicon.png"
    "/favicon-16.png"
    "/favicon-32.png"
    "/favicon-48.png"
    "/favicon-96.png"
    "/favicon-144.png"
    "/apple-icon-180.png"
    "/custom.css"
    "/feature-panel.png"
    "/dark_skeleton.png"
    "/light_skeleton.png"
    "/manifest.json"
    "/manifest-icon-192.maskable.png"
    "/manifest-icon-512.maskable.png"
    "/robots.txt"
    "/.well-known/security.txt"
    # api endpoints required by the shared link page
    "/api/server/config"
    "/api/server/features"
    "/api/shared-links/me"
    "/api/shared-links/login"
    "/api/assets/"
    "/api/albums/"
    "/api/timeline/"
    "/api/download/"
  ];
in
{
  apps.immich = {
    domain = "immich.xela";
    port = 12173;
    enableProxy = true;
    details = {
      publicDomain = "immich.xela.codes";
    };
    allowedHosts = [ "brayden" ];

    description = "Photo Organizer";
  };

  services.immich = {
    enable = true;
    #TODO:26.11 stable (remove)
    package = pkgs.unstable.immich;
    host = app.ip;
    inherit (app) port;
    # todo:
    # IMMICH_HELMET_FILE=true
  };
  systemd.services.immich-server.after = [ "tailscale-online.service" ];

  # public-facing domain for shared links
  services.nginx.virtualHosts.${app.details.publicDomain} = {
    enableACME = true;
    forceSSL = true;
    locations =
      # convert paths to proxies
      (builtins.listToAttrs (
        map (path: {
          name = path;
          value = {
            proxyPass = "http://${app.ip}:${app.portString}";
            proxyWebsockets = true;
          };
        }) publicPaths
      ))
      // {
        # redirect everything else to internal domain
        "/".return = "301 https://${app.domain}$request_uri";
      };
  };
  dnszones.list."${splitPublicDomain.domain}".subdomains."${splitPublicDomain.subdomain}" =
    xelib.dns.pointHost app.host;
}
