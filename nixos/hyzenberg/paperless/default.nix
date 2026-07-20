{
  config,
  pkgs,
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

    description = "Document Store";
    icon = "paperless-ngx";
  };

  services.paperless = {
    enable = true;
    package = pkgs.paperless-ngx;
    address = app.ip;
    inherit (app) port domain;

    database.createLocally = true;
    configureTika = true;
    consumptionDir = "/home/paperless_consume";
    consumptionDirIsPublic = true;

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
  systemd.services.paperless-web.after = [ "tailscale-online.service" ];

  sops.groups.paperless = {
    id = "op://Private/bdrrieifx4gegwpuqcrbjbykq4/OAuth/Client ID";
    secret = "op://Private/bdrrieifx4gegwpuqcrbjbykq4/OAuth/Secret";
  };

  sops.templates."paperless.env".content = xelib.toENVString {
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
              client_id = config.sops.groupPlaceholders.paperless.id;
              secret = config.sops.groupPlaceholders.paperless.secret;
              settings.server_url = xelib.apps.pocket-id.url;
            }
          ];
        };
      }
    );
  };
}
