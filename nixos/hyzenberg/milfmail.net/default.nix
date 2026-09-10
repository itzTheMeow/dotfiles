{
  dns,
  hostname,
  lib,
  xelib,
  ...
}:
let
  domain = "milfmail.net";
in
lib.mkMerge [
  {
    dnszones.list.${domain} =
      with dns.lib.combinators;
      with xelib.dns;
      lib.mkMerge [
        {
          useOrigin = true;
          inherit SOA NS TTL;
          subdomains.www = pointHost hostname;
        }
        (pointHost hostname)
        (mailcow { })
      ];
    dnszones.dnssecEnabled = [ domain ];

    nginx.redirects.${domain} = {
      dest = "https://${xelib.mail.domain}$request_uri";
      extraConfig.serverAliases = [ "www.${domain}" ];
    };

    # autoconfig
    nginx.proxy."autoconfig.${domain}" = {
      target = {
        host = xelib.apps.mailcow.ip;
        inherit (xelib.apps.mailcow) port;
      };
      extraConfig = _: {
        serverAliases = [ "autodiscover.${domain}" ];
      };
    };
  }
  (xelib.mkMtaSts domain)
]
