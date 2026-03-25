{
  config,
  lib,
  pkgs-unstable,
  xelib,
  ...
}:
let
  app = config.apps.beszel;
in
{
  apps.beszel = {
    domain = "beszel.xela";
    port = 48976;
    enableProxy = true;
  };

  services.beszel.hub = {
    enable = true;
    package = pkgs-unstable.beszel;
    host = app.ip;
    inherit (app) port;
    environment = {
      DISABLE_PASSWORD_AUTH = "true";
      USER_CREATION = "true";
    };
  };
  systemd.services.beszel-hub.after = [ "tailscale-online.service" ];

  # filter all hosts that have a beszel-agent port
  nginx.proxy.${app.domain}.allowedHosts = builtins.attrNames (
    lib.attrsets.filterAttrs (name: value: (value ? ports) && (value.ports ? beszel-agent)) xelib.hosts
  );
}
