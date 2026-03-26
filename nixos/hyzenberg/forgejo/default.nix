{
  config,
  hostname,
  lib,
  pkgs-unstable,
  xelib,
  ...
}:
let
  app = config.apps.forgejo;
  signingKeyPath = "/var/lib/forgejo/signing/id_ed25519";
in
{
  apps.forgejo = {
    domain = "forge.xela.codes";
    port = 28313;
    enableProxy = true;
  };

  services.forgejo = {
    enable = true;
    package = pkgs-unstable.forgejo;
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
        SSH_SERVER_KEY_EXCHANGES = "mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com,curve25519-sha256,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521";

        LANDING_PAGE = "/xela/"; # redirect unauthenticated users to my account
      };
      session.COOKIE_SECURE = true; # make cookies secure
      repository.DEFAULT_BRANCH = "master"; # change default branch name
      repository.USE_COMPAT_SSH_URI = false; # dont use ssh:// url
      "ui.meta".DESCRIPTION = "xela.codes personal software forge.";
      security = {
        INSTALL_LOCK = true; # disable install page
        REVERSE_PROXY_TRUSTED_PROXIES = "127.0.0.0/8,::1/128,100.64.0.0/10";
      };
      mirror.DEFAULT_INTERVAL = "1h"; # default mirror interval

      "repository.signing" = {
        FORMAT = "ssh";
        SIGNING_KEY = "${signingKeyPath}.pub";
        SIGNING_NAME = "Forgejo";
        SIGNING_EMAIL = "noreply@${app.domain}";
        DEFAULT_TRUST_MODEL = "committer";

        INITIAL_COMMIT = "always";
        WIKI = "always";
        CRUD_ACTIONS = "always";
        MERGES = "approved, commitssigned";
      };
      /*
        "git.config" = {
          "gpg.format" = "ssh";
          "gpg.ssh.program" = "${pkgs.openssh}/bin/ssh-keygen";
          "user.name" = "Forgejo";
          "user.email" = "noreply@${app.domain}";
        };
      */

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
        NO_REPLY_ADDRESS = "noreply-${config.apps.forgejo.domain}";
      };
    };
  };

  systemd.services.forgejo = {
    after = [ "tailscale-online.service" ];
    # permission to bind to port22
    serviceConfig = {
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      CapabilityBoundingSet = lib.mkForce "CAP_NET_BIND_SERVICE";
      PrivateDevices = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
    };
  };

  # signing key
  sops.secrets = {
    "forgejo-signing-key-pub" = {
      sopsFile = config.sops.opSecrets.forgejo-signing.fullPath;
      key = "pub";
      owner = "forgejo";
      path = "${signingKeyPath}.pub";
    };
    "forgejo-signing-key" = {
      sopsFile = config.sops.opSecrets.forgejo-signing.fullPath;
      key = "private";
      owner = "forgejo";
      path = signingKeyPath;
    };
  };
  sops.opSecrets.forgejo-signing.keys = {
    pub = "op://Private/s6lqgzcbzjrvvhhetoycc3dv3q/public key";
    private = "op://Private/s6lqgzcbzjrvvhhetoycc3dv3q/private key?ssh-format=openssh";
  };

  # catppuccin
  catppuccin.forgejo.enable = true;
}
