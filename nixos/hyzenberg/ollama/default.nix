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
      # leave 2 cores free for the server
      OLLAMA_NUM_THREADS = "10";
      # only do 1 request at once
      OLLAMA_NUM_PARALLEL = "1";
    };
  };
  systemd.services.ollama.after = [ "tailscale-online.service" ];
}
