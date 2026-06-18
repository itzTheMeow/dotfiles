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
    environmentVariables = {
      # leave 1 core free for the server
      OLLAMA_NUM_THREADS = "11";
    };
  };
  systemd.services.ollama.after = [ "tailscale-online.service" ];
}
