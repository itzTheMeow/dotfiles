{
  lib,
  pkgs-unstable,
  xelib,
  ...
}:
let
  svc = xelib.services.beszel;
  host = xelib.hosts.${svc.host}.ip;
in
{
  services.beszel.hub = {
    enable = true;
    package = pkgs-unstable.beszel;
    inherit host;
    inherit (svc) port;
    environment = {
      DISABLE_PASSWORD_AUTH = "true";
      USER_CREATION = "true";
    };
  };
  systemd.services.beszel-hub.after = [ "tailscale-online.service" ];

  nginx.proxy.${svc.domain} = {
    target.port = svc.port;
    # filter all hosts that have a beszel-agent port
    allowedHosts = builtins.attrNames (
      lib.attrsets.filterAttrs (name: value: (value ? ports) && (value.ports ? beszel-agent)) xelib.hosts
    );
  };
}
