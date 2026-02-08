{
  config,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  svc = xelib.services.headplane;
  headscale = xelib.services.headscale;
  headscaleConfig = xelib.toYAMLFile "headscale.yml" (
    lib.recursiveUpdate config.services.headscale.settings {
      tls_cert_path = "/dev/null";
      tls_key_path = "/dev/null";
      policy.path = "/dev/null";
    }
  );

  IP = xelib.hosts.${svc.host}.ip;
  secretFile = "/var/lib/headplane/secret.txt";
in
lib.mkMerge [
  {
    services.headplane = {
      enable = true;
      settings = {
        server = {
          host = IP;
          port = svc.port;
          cookie_secret_path = secretFile;
          cookie_max_age = 604800; # 7 days in seconds
        };
        headscale = {
          url = "https://${headscale.domain}";
          config_path = "${headscaleConfig}";
        };
        integration.agent = {
          enabled = true;
          pre_authkey_path = "/var/lib/headplane/preauth.txt";
        };
      };
    };

    # systemd service to create the cookie secret
    systemd.services.headplane-secret-generator = {
      description = "Generate Headplane cookie secret";
      wantedBy = [ "multi-user.target" ];
      before = [ "headplane.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        SECRET_FILE="${secretFile}"
        mkdir -p /var/lib/headplane
        if [ ! -f "$SECRET_FILE" ]; then
          echo "Generating new Headplane cookie secret..."
          ${pkgs.openssl}/bin/openssl rand -hex 16 > "$SECRET_FILE"
          chmod 640 "$SECRET_FILE"
          #chown headscale:headscale "$SECRET_FILE"
          echo "Secret generated at $SECRET_FILE"
        else
          echo "Secret already exists at $SECRET_FILE, skipping generation"
        fi
      '';
    };
  }
  (xelib.mkNginxProxy svc.domain "http://${IP}:${toString svc.port}" { })
]
