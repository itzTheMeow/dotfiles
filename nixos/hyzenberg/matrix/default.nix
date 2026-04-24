{
  config,
  pkgs,
  xelib,
  ...
}:
let
  app = config.apps.matrix;
in
{
  apps.matrix = {
    domain = "matrix.${xelib.domain}";
    port = 21397;
    details = {
      masPort = 21399;
    };
  };

  # synapse
  services.matrix-synapse = {
    enable = true;
    extras = [ "oidc" ];
    settings = {
      enable_registration = false;
      max_upload_size = "1G";
      public_baseurl = app.url;
      server_name = xelib.domain;
      password_config.enabled = false;
      matrix_authentication_service = {
        enabled = true;
        issuer = app.url;
        endpoint = "http://${app.ip}:${toString app.details.masPort}";
        secret_path = config.sops.secrets.matrix-synapse-mas-secret.path;
      };

      listeners = [
        {
          port = app.port;
          bind_addresses = [ app.ip ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [ "client" ];
              compress = true;
            }
            {
              names = [
                "federation"
                "openid"
              ];
              compress = false;
            }
          ];
        }
      ];
    };
  };
  systemd.services.matrix-synapse.after = [ "tailscale-online.service" ];
  services.postgresql = {
    ensureUsers = [
      {
        name = "matrix-synapse";
      }
    ];
    # synapse is annoying
    # https://nixos.org/manual/nixos/stable/index.html#module-services-matrix-synapse
    initialScript = pkgs.writeText "init-synapse-db.sql" ''
      CREATE ROLE "matrix-synapse";
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';
  };

  # mas
  services.matrix-authentication-service = {
    enable = true;
    createDatabase = true;

    settings = {
      http = {
        public_base = app.url;
        listeners = [
          {
            name = "web";
            resources = [
              { name = "discovery"; }
              { name = "human"; }
              { name = "oauth"; }
              { name = "compat"; }
              { name = "graphql"; }
              { name = "assets"; }
            ];
            binds = [
              {
                host = app.ip;
                port = app.details.masPort;
              }
            ];
            proxy_protocol = false;
          }
          {
            name = "internal";
            resources = [
              { name = "health"; }
            ];
            binds = [
              {
                host = "127.0.0.1";
                port = 12352;
              }
            ];
            proxy_protocol = false;
          }
        ];
      };

      secrets.keys = [
        {
          kid = "primary-signing-key";
          key_file = config.sops.secrets.matrix-synapse-mas-rsa.path;
        }
      ];

      matrix = {
        homeserver = xelib.domain;
        endpoint = "http://${app.ip}:${app.portString}";
      };

      passwords.enabled = false;
    };

    extraConfigFiles = [ config.sops.templates."matrix-synapse-oidc.yaml".path ];
  };

  sops.opSecrets.matrix-synapse.keys = {
    masRSA = "op://Private/6xrchf67gk2l53glqwdmjhkavu/emnvkabz6cxppmfpab5dhzy2o4";
    masSecret = "op://Private/6xrchf67gk2l53glqwdmjhkavu/MAS Secret";
    masKey = "op://Private/6xrchf67gk2l53glqwdmjhkavu/MAS Key";
    client = "op://Private/6xrchf67gk2l53glqwdmjhkavu/username";
    secret = "op://Private/6xrchf67gk2l53glqwdmjhkavu/credential";
  };

  sops.secrets.matrix-synapse-mas-secret = {
    sopsFile = config.sops.opSecrets.matrix-synapse.fullPath;
    key = "masSecret";
  };
  sops.secrets.matrix-synapse-mas-key = {
    sopsFile = config.sops.opSecrets.matrix-synapse.fullPath;
    key = "masKey";
  };
  sops.secrets.matrix-synapse-oidc-client = {
    sopsFile = config.sops.opSecrets.matrix-synapse.fullPath;
    key = "client";
  };
  sops.secrets.matrix-synapse-oidc-secret = {
    sopsFile = config.sops.opSecrets.matrix-synapse.fullPath;
    key = "secret";
  };
  sops.secrets.matrix-synapse-mas-rsa = {
    sopsFile = config.sops.opSecrets.matrix-synapse.fullPath;
    key = "masRSA";
    owner = "matrix-authentication-service";
  };
  sops.templates."matrix-synapse-oidc.yaml" = {
    content = xelib.toYAMLString {
      matrix.secret = config.sops.placeholder.matrix-synapse-mas-secret;

      secrets.encryption = config.sops.placeholder.matrix-synapse-mas-key;

      upstream_oauth2.providers = [
        {
          id = "01KPZDCTG6RFS2E102SATDDAAQ";
          issuer = xelib.apps.pocket-id.url;
          client_id = config.sops.placeholder.matrix-synapse-oidc-client;
          client_secret = config.sops.placeholder.matrix-synapse-oidc-secret;
          token_endpoint_auth_method = "client_secret_basic";
          scope = "openid profile email";
          claims_imports = {
            localpart.template = "{{ user.preferred_username }}";
            displayname.template = "{{ user.name }}";
          };
        }
      ];
    };
    owner = "matrix-authentication-service";
  };

  services.nginx.virtualHosts.${app.domain} = {
    enableACME = true;
    forceSSL = true;

    locations = {
      # forward OIDC and MAS-specific paths to MAS
      "~ ^/(.well-known/openid-configuration|oidc|login|logout|refresh)" = {
        proxyPass = "http://${app.ip}:${toString app.details.masPort}";
        priority = 1;
      };

      # forward specific Matrix 2.0 Auth endpoints to MAS
      "~ ^/_matrix/client/(.*)/(login|logout|refresh)" = {
        proxyPass = "http://${app.ip}:${toString app.details.masPort}";
        priority = 1;
      };

      # forward everything else to Synapse
      "/" = {
        proxyPass = "http://${app.ip}:${app.portString}";
        extraConfig = ''
          client_max_body_size 1G;
        '';
        priority = 2;
      };
    };
  };
}
