{ config, ... }:
let
  app = config.apps.ollama;
in
{
  apps.ollama.port = 11484;

  services.ollama = {
    enable = true;
    host = app.ip;
    inherit (app) port;
    syncModels = true;
  };
  systemd.services.ollama.after = [ "tailscale-online.service" ];
}
