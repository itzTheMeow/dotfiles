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

  legacyIP = "5.161.177.144";
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
        "*".A = [ (a legacyIP) ];
        www = pointHost hostname;

        # legacy apt server
        apt.CNAME = [ (cname (fqdn "itzthemeow.github.io")) ];

        # legacy dns routing records
        ehrman = pointHost "ehrman";
        hyzenberg = pointHost "hyzenberg";
        hyzen.A = [ (a legacyIP) ];
      };
    }
    # main website
    // (pointHost "hyzenberg");
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
}
