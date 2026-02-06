{
  pkgs,
  xelib,
  ...
}:
let
  address = xelib.hosts.hyzenberg.ip;
  port = xelib.services.step-ca.port;
in
{
  # we want the cli to work too
  environment.systemPackages = [ pkgs.step-cli ];

  services.step-ca = {
    enable = true;
    inherit address port;
    # password must be put here from 1password
    intermediatePasswordFile = "/var/lib/step-ca/password.txt";
    settings = {
      root = "/var/lib/step-ca/certs/root_ca.crt";
      federatedRoots = null;
      crt = "/var/lib/step-ca/certs/intermediate_ca.crt";
      key = "/var/lib/step-ca/secrets/intermediate_ca_key";
      address = "${address}:${toString port}";
      insecureAddress = "";
      dnsNames = [
        "localhost"
        "hyzenberg"
        address
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
              # issued certificates will expire after 14 days
              defaultTLSCertDuration = "336h";
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

  # start on boot and wait for tailscale
  systemd.services.step-ca = {
    after = [
      "network-online.target"
      "tailscale-online.service"
    ];
    wants = [ "network-online.target" ];
  };
}
