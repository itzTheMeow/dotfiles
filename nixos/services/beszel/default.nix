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
lib.mkMerge [
  {
    services.beszel.hub = {
      enable = true;
      package = pkgs-unstable.beszel;
      inherit host;
      port = svc.port;
      environment = {
        DISABLE_PASSWORD_AUTH = "true";
        USER_CREATION = "true";
      };
    };
    systemd.services.beszel-hub.after = [ "tailscale-online.service" ];
  }
  (xelib.mkNginxProxy svc.domain "http://${host}:${toString svc.port}" {
    # filter all hosts that have a beszel-agent port
    allowedHosts = builtins.attrNames (
      lib.attrsets.filterAttrs (name: value: (value ? ports) && (value.ports ? beszel-agent)) xelib.hosts
    );
  })
]
