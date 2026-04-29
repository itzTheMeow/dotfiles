{
  config,
  dns,
  hostname,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  app = config.apps.mailcow;

  mkMailSRV = service: port: {
    inherit service port;
    proto = "tcp";
    target = xelib.dns.fqdn xelib.mail.domain;
  };
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
    fixed-cidr-v6 = "${lib.removeSuffix "1" xelib.dns.addr6.${hostname}}/64";
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
  security.acme.certs.${app.domain}.postRun =
    let
      docker = "${pkgs.docker}/bin/docker";
    in
    ''
      cp fullchain.pem /opt/mailcow-dockerized/data/assets/ssl/cert.pem
      cp key.pem /opt/mailcow-dockerized/data/assets/ssl/key.pem

      # restart required services
      # https://docs.mailcow.email/post_installation/firststeps-ssl/#how-to-use-your-own-certificate
      ${docker} restart ${
        pkgs.lib.concatStringsSep " " (
          pkgs.lib.map (name: "$(${docker} ps -qaf name=${name})") [
            "postfix-mailcow"
            "nginx-mailcow"
            "dovecot-mailcow"
          ]
        )
      }
    '';

  dnszones.list.${xelib.domain} =
    with dns.lib.combinators;
    with xelib.dns;
    lib.mkMerge [
      {
        SRV = [
          (mkMailSRV "caldavs" 443)
          (mkMailSRV "carddavs" 443)
          (mkMailSRV "imaps" 993)
          (mkMailSRV "imap" 143)
          (mkMailSRV "smtps" 465)
          (mkMailSRV "submission" 587)
        ];
        subdomains = {
          mail = pointHost hostname;
          "_25._tcp.mail".TLSA = [
            {
              certUsage = "dane-ee";
              selector = "spki";
              matchingType = "sha256";
              certificate = "352cba4e587a76233644a4c40d0a94c5cc2387a2c42fb903ad5eb937157a33e8";
            }
          ];
          "_caldavs._tcp".TXT = [ (txt "path=/SOGo/dav/") ];
          "_carddavs._tcp".TXT = [ (txt "path=/SOGo/dav/") ];
        };
      }
      (mailcow { })
    ];

  # add autoconfig/autodiscover to the ssl/proxy
  nginx.proxy.${app.domain}.extraConfig = _: {
    serverAliases = [
      "autoconfig.${xelib.domain}"
      "autodiscover.${xelib.domain}"
    ];
  };
}
