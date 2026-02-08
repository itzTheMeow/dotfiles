{ pkgs, ... }:
let
  defaultCertDir = "/var/lib/acme/default-cert";
in
{
  # enable and configure NGINX
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "1g";

    # default catch-all host for random requests
    virtualHosts."_" = {
      default = true;
      locations."/" = {
        return = "404 'NOT FOUND'";
        extraConfig = ''
          default_type text/plain;
        '';
      };
      # add self-signed cert for SSL catch-all
      addSSL = true;
      sslCertificate = "${defaultCertDir}/fullchain.pem";
      sslCertificateKey = "${defaultCertDir}/key.pem";
    };
  };

  # generate a dummy 100-year cert for catchall requests
  systemd.services.nginx-default-cert = {
    description = "Generate self-signed certificate for nginx default server";
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      CERT_DIR="${defaultCertDir}"
      mkdir -p "$CERT_DIR"
      if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
        echo "Generating self-signed certificate for nginx default server..."
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
          -keyout "$CERT_DIR/key.pem" \
          -out "$CERT_DIR/fullchain.pem" \
          -days 36500 \
          -subj "/CN=_"
        chmod 640 "$CERT_DIR"/*.pem
        chown -R nginx:nginx "$CERT_DIR"
        echo "Certificate generated at $CERT_DIR"
      fi
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  # add nginx user to acme group so it can read challenge files
  users.users.nginx.extraGroups = [ "acme" ];
}
