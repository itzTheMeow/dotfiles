{
  config,
  hostname,
  xelib,
  ...
}:
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
    # https://forgejo.org/docs/latest/admin/config-cheat-sheet/
    settings = {
      server = {
        ROOT_URL = app.url;
        DOMAIN = app.domain;
        HTTP_ADDR = app.ip;
        HTTP_PORT = app.port;

        # use internal ssh server on public IP
        START_SSH_SERVER = true;
        SSH_LISTEN_HOST = xelib.dns.addr.${hostname};

        LANDING_PAGE = "/xela.codes/"; # redirect unauthenticated users to my account
      };
      session.COOKIE_SECURE = true; # make cookies secure
      repository.DEFAULT_BRANCH = "master"; # change default branch name
      "ui.meta".DESCRIPTION = "xela.codes personal software forge.";
      security.INSTALL_LOCK = true; # disable install page
      mirror.DEFAULT_INTERVAL = "1h"; # default mirror interval

      # configure oidc
      openid.ENABLE_OPENID_SIGNUP = true;
      oauth2_client = {
        REGISTER_EMAIL_CONFIRM = true;
        ENABLE_AUTO_REGISTRATION = true;
        UPDATE_AVATAR = true;
      };

      service = {
        DISABLE_REGISTRATION = true;
        ENABLE_INTERNAL_SIGNIN = false;
        DEFAULT_KEEP_EMAIL_PRIVATE = true;
        DEFAULT_ORG_MEMBER_VISIBLE = true;
        NO_REPLY_ADDRESS = "noreply.DOMAIN";
      };
    };
  };
}
