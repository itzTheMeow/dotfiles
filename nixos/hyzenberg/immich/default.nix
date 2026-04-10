{
  config,
  pkgs-unstable,
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
  };

  services.immich = {
    enable = true;
    package = pkgs-unstable.immich;
    host = app.ip;
    inherit (app) port;
    # todo:
    # IMMICH_HELMET_FILE=true
  };
  systemd.services.immich-server.after = [ "tailscale-online.service" ];
}
