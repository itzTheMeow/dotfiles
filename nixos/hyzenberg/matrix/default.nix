{ config, xelib, ... }:
let
  app = config.apps.matrix;
in
{
  apps.matrix = {
    domain = "matrix.${xelib.domain}";
    port = 21397;
    enableProxy = true;
  };

  services.matrix-synapse = {
    enable = true;
    extras = [ "oidc" ];
    settings = {
      enable_registration = false;
      max_upload_size = "1G";
      public_baseurl = app.url;
      server_name = xelib.domain;
      password_config.enabled = false;

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
    extraConfigFiles = [ config.sops.templates."matrix-synapse-oidc.yaml".path ];
  };
  systemd.services.matrix-synapse.after = [ "tailscale-online.service" ];

  services.postgresql = {
    ensureDatabases = [ "matrix-synapse" ];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };

  sops.secrets.matrix-synapse-oidc-client = {
    sopsFile = config.sops.opSecrets.matrix-synapse.fullPath;
    key = "client";
  };
  sops.secrets.matrix-synapse-oidc-secret = {
    sopsFile = config.sops.opSecrets.matrix-synapse.fullPath;
    key = "secret";
  };
  sops.opSecrets.matrix-synapse.keys = {
    client = "op://Private/6xrchf67gk2l53glqwdmjhkavu/username";
    secret = "op://Private/6xrchf67gk2l53glqwdmjhkavu/credential";
  };
  sops.templates."matrix-synapse-oidc.yaml" = {
    content = xelib.toYAMLString {
      # https://element-hq.github.io/synapse/latest/openid.html#pocket-id
      oidc_providers = [
        {
          idp_id = "pocket_id";
          idp_name = "Pocket ID";
          issuer = xelib.apps.pocket-id.url;
          client_id = config.sops.placeholder.matrix-synapse-oidc-client;
          client_secret = config.sops.placeholder.matrix-synapse-oidc-secret;
          scopes = [
            "openid"
            "profile"
          ];
          user_mapping_provider.config = {
            localpart_template = "{{ user.preferred_username }}";
            display_name_template = "{{ user.name }}";
          };
        }
      ];
    };
    owner = "matrix-synapse";
  };
}
