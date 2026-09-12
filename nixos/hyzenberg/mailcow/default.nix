{
  config,
  dns,
  host,
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

  updateModule = import ./update.nix { inherit config lib pkgs; };
in
lib.mkMerge [
  updateModule
  {
    apps.mailcow = {
      domain = "mail.xela.codes";
      port = 8099; # set in mailcow.conf
      enableProxy = true;
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

    # nightly check that the DANE-TA pin still matches the served chain
    systemd.services.mailcow-dane-check =
      let
        home = "/home/${host.username}";
        daneCheck = pkgs.writeShellApplication {
          name = "check-dane";
          runtimeInputs = with pkgs; [
            coreutils
            dnsutils
            gawk
            ntfy-sh
            openssl
          ];
          text = builtins.readFile ./check-dane.sh;
        };
      in
      {
        description = "Verify DANE-TA pin for ${app.domain}";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${daneCheck}/bin/check-dane ${app.domain}";
          Environment = [
            "HOME=${home}"
            "NTFY_CONFIG=${home}/.config/ntfy/client.yml"
            "NTFY_TOPIC=${xelib.globals.environment.NTFY_TOPIC}"
            "NTFY_TAGS=mail"
          ];
        };
      };
    systemd.timers.mailcow-dane-check = {
      description = "Nightly DANE-TA pin check for ${app.domain}";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 00:00:00";
        Persistent = true;
      };
    };

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
                certUsage = "dane-ta";
                selector = "spki";
                matchingType = "sha256";
                certificate = "6ebcefb4210b088654a38b03fea3d7d1c711b4fb1ddc363a45f9b1a4e53da01e";
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
  (xelib.mkMtaSts xelib.domain)
]
