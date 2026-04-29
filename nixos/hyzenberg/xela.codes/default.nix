{
  dns,
  hostname,
  xelib,
  ...
}:
let
  legacyIP = "5.161.177.144";
in
{
  dnszones.list.${xelib.domain} =
    with dns.lib.combinators;
    with xelib.dns;
    {
      useOrigin = true;
      inherit SOA NS TTL;
      A = [ (a legacyIP) ];
      subdomains = {
        "*".A = [ (a legacyIP) ];
        www = pointHost hostname;

        # legacy apt server
        apt.CNAME = [ (cname (fqdn "itzthemeow.github.io")) ];

        # legacy dns routing records
        ehrman = pointHost "ehrman";
        hyzenberg = pointHost "hyzenberg";
        hyzen.A = [ (a legacyIP) ];
      };
    };
  dnszones.dnssecEnabled = [ xelib.domain ];
}
