{ config, ... }:
let
  app = config.apps.atuin-server;
in
{
  apps.atuin-server = {
    port = 46973;
  };

  services.atuin = {
    enable = true;
    host = app.ip;
    port = app.port;
  };
}
