{
  config,
  pkgs,
  xelib,
  ...
}:
let
  tailscaleIP = xelib.hosts.hyzenberg.ip;
  caPort = xelib.services.step-ca.port;
in
{
  services.step-ca = {
    enable = true;
    address = tailscaleIP;
    port = caPort;
    intermediatePasswordFile = "/var/lib/step-ca/password.txt";
    settings = {
      root = "/var/lib/step-ca/certs/root_ca.crt";
      federatedRoots = null;
      crt = "/var/lib/step-ca/certs/intermediate_ca.crt";
      key = "/var/lib/step-ca/secrets/intermediate_ca_key";
      address = "${tailscaleIP}:${toString caPort}";
      insecureAddress = "";
      dnsNames = [
        "localhost"
        "hyzenberg"
        tailscaleIP
      ];
      logger = {
        format = "text";
      };
      db = {
        type = "badgerv2";
        dataSource = "/var/lib/step-ca/db";
        badgerFileLoadingMode = "";
      };
      authority = {
        provisioners = [
          {
            type = "ACME";
            name = "acme";
            claims = {
              defaultTLSCertDuration = "336h"; # 14 days
              maxTLSCertDuration = "336h";
            };
          }
        ];
      };
      tls = {
        cipherSuites = [
          "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
          "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        ];
        minVersion = 1.2;
        maxVersion = 1.3;
        renegotiation = false;
      };
    };
  };

  # Ensure the step-ca service starts on boot
  systemd.services.step-ca = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
