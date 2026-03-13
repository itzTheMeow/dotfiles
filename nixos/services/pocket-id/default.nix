{
  config,
  lib,
  pkgs-unstable,
  xelib,
  ...
}:
let
  svc = xelib.services.nzbget;
in
lib.mkMerge [
  {
    services.pocket-id = {
      enable = true;
      package = pkgs-unstable.pocket-id;
      settings = {
        HOST = xelib.hosts.${svc.host}.ip;
        PORT = svc.port;
        APP_URL = "https://${svc.domain}";
        TRUST_PROXY = true;
        #TODO:nix-26.05 switch to credentials option
        ENCRYPTION_KEY_FILE = config.sops.secrets.pocket-id-enc.path;
        MAXMIND_LICENSE_KEY_FILE = config.sops.secrets.pocket-id-maxmind.path;
      };
    };

    sops.secrets.pocket-id-enc = {
      sopsFile = ../../../${config.sops.opSecrets.pocket-id.path};
      key = "key";
    };
    sops.secrets.pocket-id-maxmind = {
      sopsFile = ../../../${config.sops.opSecrets.pocket-id.path};
      key = "license";
    };
    sops.opSecrets = {
      pocket-id.keys = {
        key = "op://Private/pwdsgmanpl46sqdbxfsa7ylzzq/credential";
        licence = "op://Private/yo5ksl7xuwir3ab3idjpjccaty/ko4vnnqfnsekir7iss47wdawvq/pzru4hfyoodf34v7uys6cee3ra";
      };
    };
  }
  (xelib.mkNginxProxy svc.domain "http://${xelib.hosts.${svc.host}.ip}:${toString svc.port}" { })
]
