{
  config,
  inputs,
  pkgs-unstable,
  ...
}:
let
  app = config.apps.pocket-id;
in
{
  #TODO:nixos-26.05 replace the module with the one from unstable
  disabledModules = [ "services/security/pocket-id.nix" ];
  imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/services/security/pocket-id.nix" ];

  apps.pocket-id = {
    domain = "auth.xela.codes";
    port = 11171;
    enableProxy = true;
  };

  services.pocket-id = {
    enable = true;
    package = pkgs-unstable.pocket-id;
    settings = {
      HOST = app.ip;
      PORT = app.port;
      APP_URL = app.url;
      TRUST_PROXY = true;
    };
    credentials = {
      ENCRYPTION_KEY = config.sops.secrets.pocket-id-enc.path;
      MAXMIND_LICENSE_KEY = config.sops.secrets.pocket-id-maxmind.path;
    };
  };
  systemd.services.pocket-id.after = [ "tailscale-online.service" ];

  sops.secrets.pocket-id-enc = {
    sopsFile = config.sops.opSecrets.pocket-id.fullPath;
    key = "key";
  };
  sops.secrets.pocket-id-maxmind = {
    sopsFile = config.sops.opSecrets.pocket-id.fullPath;
    key = "license";
  };
  sops.opSecrets.pocket-id.keys = {
    key = "op://Private/pwdsgmanpl46sqdbxfsa7ylzzq/credential";
    license = "op://Private/yo5ksl7xuwir3ab3idjpjccaty/ko4vnnqfnsekir7iss47wdawvq/pzru4hfyoodf34v7uys6cee3ra";
  };
}
