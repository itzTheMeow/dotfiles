{
  dns,
  hostname,
  lib,
  xelib,
  ...
}:
let
  domain = "itsmeow.cat";
in
{
  dnszones.list.${domain} =
    with dns.lib.combinators;
    with xelib.dns;
    lib.mkMerge [
      {
        useOrigin = true;
        inherit SOA NS TTL;
        subdomains = {
          www = pointHost hostname;

          github.CNAME = [ (cname (fqdn "itzthemeow.github.io")) ];
        };
      }
      (pointHost hostname)
      (mailcow { })
    ];
  dnszones.dnssecEnabled = [ domain ];

  nginx.redirects.${domain} = {
    dest = "https://${xelib.domain}$request_uri";
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
