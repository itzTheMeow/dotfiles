{
  config,
  dns,
  hostname,
  pkgs,
  xelib,
  ...
}:
let
  app = config.apps.xela-website;
  webPackage = pkgs.callPackage ./package.nix { };
in
{
  apps.xela-website = {
    domain = xelib.domain;
    port = 23197;
    enableProxy = true;
  };

  dnszones.list.${xelib.domain} =
    with dns.lib.combinators;
    with xelib.dns;
    {
      useOrigin = true;
      inherit SOA NS TTL;
      subdomains = {
        www = pointHost hostname;

        # legacy:svolte
        svolte = pointHost hostname;

        # legacy apt server
        apt.CNAME = [ (cname (fqdn "itzthemeow.github.io")) ];

        # legacy dns routing records
        ehrman = pointHost "ehrman";
        hyzenberg = pointHost "hyzenberg";
      };
    }
    # main website
    // (pointHost hostname);
  dnszones.dnssecEnabled = [ xelib.domain ];

  systemd.services.xela-website = {
    description = "xela.codes website service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${webPackage}/bin/xela-website";

      # hardening
      DynamicUser = true;
      ProtectSystem = "strict";
      CapabilityBoundingSet = "";
    };

    environment = {
      PORT = app.portString;
    };
  };

  # redirect `www.` to root
  nginx.redirects."www.${xelib.domain}".dest = app.url + "$request_uri";

  # redirect legacy hyzen.xela.codes domains to root
  nginx.redirects."hyzen.${xelib.domain}".dest = app.url + "$request_uri";

  # legacy:svolte
  nginx.redirects."svolte.${xelib.domain}".dest =
    xelib.apps.forgejo.url + "/xela-archive/revolt-svolte#svolte";
}
