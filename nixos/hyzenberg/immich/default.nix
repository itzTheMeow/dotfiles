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
  };

  services.immich = {
    enable = true;
    package = pkgs-unstable.immich;
    host = app.ip;
    inherit (app) port;
  };
}
