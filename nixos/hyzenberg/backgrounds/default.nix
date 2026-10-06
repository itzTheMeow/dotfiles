{
  config,
  pkgs,
  ...
}:
let
  app = config.apps.backgrounds;
  server = pkgs.callPackage ./package.nix { };

  refreshSeconds = 4 * 60 * 60; # reshuffle every 4 hours
  urls = import ./urls.nix;

  configFile = (pkgs.formats.json { }).generate "backgrounds.json" {
    inherit urls refreshSeconds;
  };
in
{
  apps.backgrounds = {
    domain = "backgrounds.xela";
    port = 50977;
    enableProxy = true;
  };

  systemd.services.backgrounds = {
    description = "Backgrounds image shuffle server";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "tailscale-online.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${server}/bin/backgrounds";
      Environment = [
        "BACKGROUNDS_CONFIG=${configFile}"
        "BACKGROUNDS_ADDR=${app.ip}:${app.portString}"
        "BACKGROUNDS_STATE_DIR=/var/lib/backgrounds"
      ];
      DynamicUser = true;
      StateDirectory = "backgrounds";
      Restart = "on-failure";
      RestartSec = 10;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/backgrounds" ];
    };
  };
}
