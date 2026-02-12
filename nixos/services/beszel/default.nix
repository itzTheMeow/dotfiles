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
  }
  (xelib.mkNginxProxy svc.domain "http://${host}:${toString svc.port}" { })
]
