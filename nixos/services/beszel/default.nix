{ xelib, ... }:
let
  svc = xelib.services.beszel;
in
{
  services.beszel.hub = {
    enable = true;
    host = xelib.hosts.${svc.host}.ip;
    port = svc.port;
    environment = {
      DISABLE_PASSWORD_AUTH = true;
      USER_CREATION = true;
    };
  };
}
