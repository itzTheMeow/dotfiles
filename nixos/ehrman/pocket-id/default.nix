{
  config,
  pkgs,
  xelib,
  ...
}:
let
  app = config.apps.pocket-id;
in
{
  apps.pocket-id = {
    domain = "auth.${xelib.domain}";
    port = 11171;
    enableProxy = true;
    enableDNS = true;

    name = "Pocket ID";
    description = "OIDC Provider";
  };

  services.pocket-id = {
    enable = true;
    package = pkgs.pocket-id;
    settings = {
      HOST = app.ip;
      PORT = app.port;
      APP_URL = app.url;
      TRUST_PROXY = true;
    };
    credentials = {
      ENCRYPTION_KEY = config.sops.groupPaths.pocket-id.key;
      MAXMIND_LICENSE_KEY = config.sops.groupPaths.pocket-id.maxmind-license;
    };
  };
  systemd.services.pocket-id.after = [ "tailscale-online.service" ];

  sops.groups.pocket-id = {
    key = "op://Private/pwdsgmanpl46sqdbxfsa7ylzzq/credential";
    maxmind-license = "op://Private/yo5ksl7xuwir3ab3idjpjccaty/ko4vnnqfnsekir7iss47wdawvq/pzru4hfyoodf34v7uys6cee3ra";
  };
}
