{
  config,
  pkgs-unstable,
  xelib,
  ...
}:
let
  app = config.apps.paperless;
in
{
  apps.paperless = {
    domain = "paperless.xela";
    port = 13003;
    enableProxy = true;
  };

  services.paperless = {
    enable = true;
    package = pkgs-unstable.paperless-ngx;
    address = app.ip;
    inherit (app) port domain;

    database.createLocally = true;
    configureTika = true;

    settings = {
      PAPERLESS_DISABLE_REGULAR_LOGIN = true;
      PAPERLESS_OCR_LANGUAGE = "eng";
      PAPERLESS_OCR_USER_ARGS = {
        continue_on_soft_render_error = true;
      };
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
    };
    environmentFile = config.sops.templates."paperless.env".path;
  };

  sops.secrets.paperless-clientid = {
    sopsFile = config.sops.opSecrets.paperless.fullPath;
    key = "id";
  };
  sops.secrets.paperless-clientsecret = {
    sopsFile = config.sops.opSecrets.paperless.fullPath;
    key = "secret";
  };
  sops.secrets.paperless-secretkey = {
    sopsFile = config.sops.opSecrets.paperless.fullPath;
    key = "secretKey";
  };
  sops.opSecrets.paperless.keys = {
    id = "op://Private/bdrrieifx4gegwpuqcrbjbykq4/OAuth/Client ID";
    secret = "op://Private/bdrrieifx4gegwpuqcrbjbykq4/OAuth/Secret";
    secretKey = "op://Private/bdrrieifx4gegwpuqcrbjbykq4/App Secret Key";
  };
  sops.templates."paperless.env".content = xelib.toENVString {
    PAPERLESS_SECRET_KEY = config.sops.placeholder.paperless-secretkey;
    # escape quotes
    PAPERLESS_SOCIALACCOUNT_PROVIDERS = builtins.replaceStrings [ "\"" ] [ "\\\"" ] (
      builtins.toJSON {
        openid_connect = {
          SCOPE = [
            "openid"
            "profile"
            "email"
          ];
          OAUTH_PKCE_ENABLED = true;
          APPS = [
            {
              provider_id = "pocket-id";
              name = "Pocket ID";
              client_id = config.sops.placeholder.paperless-clientid;
              secret = config.sops.placeholder.paperless-clientsecret;
              settings.server_url = xelib.apps.pocket-id.url;
            }
          ];
        };
      }
    );
  };
}
