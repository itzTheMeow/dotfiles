{
  config,
  pkgs,
  ...
}:
let
  app = config.apps.ytmusic;
  ytmusic = pkgs.callPackage ./package.nix { };
in
{
  apps.ytmusic = {
    domain = "ytmusic.xela";
    port = 13287;
    enableProxy = true;
  };

  systemd.services.ytmusic = {
    description = "YTMusic service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${ytmusic}/bin/ytmusic";
      StateDirectory = "ytmusic";

      # hardening
      DynamicUser = true;
      ProtectSystem = "strict";
      CapabilityBoundingSet = "";

      # bind music path
      ProtectHome = "read-only";
      BindReadOnlyPaths = [ "/home/meow" ];
    };

    environment = {
      PORT = app.portString;
      BASE_DIR = "/var/lib/ytmusic";
    };
  };
}
