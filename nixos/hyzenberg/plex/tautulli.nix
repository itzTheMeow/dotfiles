{ config, ... }:
let
  app = config.apps.tautulli;
in
{
  apps.tautulli = {
    domain = "tautulli.xela";
    port = 12893;
    enableProxy = true;

    description = "Plex Monitor";
  };

  # all of the internal data is still "plexpy"
  services.tautulli = {
    enable = true;
    inherit (app) port;
  };
  systemd.services.tautulli.after = [ "tailscale-online.service" ];
}
