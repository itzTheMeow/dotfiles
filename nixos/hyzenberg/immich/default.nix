{
  config,
  pkgs,
  ...
}:
let
  app = config.apps.immich;
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
    package = pkgs.immich;
    host = app.ip;
    inherit (app) port;
    # todo:
    # IMMICH_HELMET_FILE=true
  };
  systemd.services.immich-server.after = [ "tailscale-online.service" ];
}
