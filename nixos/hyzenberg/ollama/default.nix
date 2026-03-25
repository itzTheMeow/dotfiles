{ xelib, ... }:
let
  svc = xelib.services.ollama;
in
{
  services.ollama = {
    enable = true;
    host = xelib.hosts.${svc.host}.ip;
    port = svc.port;
    syncModels = true;
  };
}
