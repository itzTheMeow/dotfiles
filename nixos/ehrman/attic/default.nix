{ config, ... }:
let
  app = config.apps.attic;
in
{
  apps.attic = {
    domain = "attic.xela.codes";
    port = 29073;
    enableProxy = true;
    enableDNS = true;
  };

  #?INIT:
  #  local admin token (if needed)
  #? atticd-atticadm make-token --sub admin --validity '999 years' \
  #?   --create-cache '*' --configure-cache '*' \
  #?   --configure-cache-retention '*' --destroy-cache '*'
  #  actually create the cache
  #? attic cache create master
  #  make cache public
  #? attic cache configure --public master
  #  get public key for nix config
  #  use public key in nixos/common.nix and flake.nix
  #? attic cache info master
  #  create a token for CI with push perms
  #? atticd-atticadm make-token --sub ci --validity '999 years' --push '*'
  #  store that in GitHub secrets as ATTIC_TOKEN

  services.atticd = {
    enable = true;
    environmentFile = config.sops.secrets.attic.path;
    settings = {
      listen = "${app.ip}:${app.portString}";
      api-endpoint = "${app.url}/";
      allowed-hosts = [ app.domain ];
      "garbage-collection" = {
        interval = "12 hours";
        #                          DD   HH   MM   SS
        default-retention-period = 30 * 24 * 60 * 60;
      };
    };
  };
  systemd.services.atticd.after = [ "tailscale-online.service" ];

  # allow big binaries to be pushed
  nginx.proxy.${app.domain}.extraConfig = _: {
    extraConfig = ''
      client_max_body_size 3g;
    '';
  };

  sops.envFiles.attic = {
    ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64 = "op://Private/kbmwv3qqjiufkdffc25svnfvd4/credential";
  };
}
