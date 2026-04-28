{ config, ... }:
let
  app = config.apps.mailcow;
in
{
  apps.mailcow = {
    domain = "mail.xela.codes";
    port = 8099; # set in mailcow.conf
    enableProxy = true;
  };

  # enable ipv6 support for docker
  virtualisation.docker.daemon.settings = {
    ipv6 = true;
    ip6tables = true;
    # address of hyzen, needs changed if host moves
    fixed-cidr-v6 = "2a0a:4cc0:2000:a0bb::/64";
  };

  # open required ports
  # https://docs.mailcow.email/getstarted/prerequisite-system/#incoming-ports
  networking.firewall.allowedTCPPorts = [
    25 # SMTP
    465 # SMTPS
    587 # Submission
    143 # IMAP
    993 # IMAPS
    110 # POP3
    995 # POP3S
    4190 # ManageSieve
  ];

  # copy over new ssl certs when generated
  security.acme.certs.${app.domain}.postRun = ''
    cp fullchain.pem /opt/mailcow-dockerized/data/assets/ssl/cert.pem
    cp key.pem /opt/mailcow-dockerized/data/assets/ssl/key.pem
  '';
}
