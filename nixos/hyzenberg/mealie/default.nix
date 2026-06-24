{ config, xelib, ... }:
let
  app = config.apps.mealie;
in
{
  apps.mealie = {
    domain = "mealie.xela";
    port = 12398;
    enableProxy = true;

    description = "Recipe book";
  };

  services.mealie = {
    enable = true;
    listenAddress = app.ip;
    inherit (app) port;
    settings = {
      BASE_URL = app.url;
      TOKEN_TIME = toString (24 * 7); # auth token valid for a week
      ALLOW_PASSWORD_LOGIN = "false"; # disable password-based login

      # oidc config
      OIDC_AUTH_ENABLED = "true";
      OIDC_CONFIGURATION_URL = "${xelib.apps.pocket-id.url}/.well-known/openid-configuration";
      OIDC_ADMIN_GROUP = "admin"; # give admin to admin groups
      OIDC_PROVIDER_NAME = xelib.apps.pocket-id.name;
    };
    credentialsFile = config.sops.secrets.mealie.path;
    database.createLocally = true;
  };
  systemd.services.mealie.after = [ "tailscale-online.service" ];

  sops.envFiles.mealie = {
    OIDC_CLIENT_ID = "op://Private/5dxndce353zdpepy5ppjusjxxi/username";
    OIDC_CLIENT_SECRET = "op://Private/5dxndce353zdpepy5ppjusjxxi/credential";
  };
}
