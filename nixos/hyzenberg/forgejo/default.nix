{ config, ... }:
let
  app = config.apps.forgejo;
in
{
  apps.forgejo = {
    domain = "forge.xela.codes";
    port = 28313;
    enableProxy = true;
  };

  services.forgejo = {
    enable = true;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        ROOT_URL = app.url;
        DOMAIN = app.domain;
        HTTP_ADDR = app.ip;
        HTTP_PORT = app.port;
      };
      session.COOKIE_SECURE = true;
    };
  };
}
