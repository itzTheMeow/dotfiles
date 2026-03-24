{ dns, xelib, ... }:
{
  dnszones.list =
    with dns.lib.combinators;
    with xelib.dns;
    {
      "milfmail.net" = lib.mkMerge [
        {
          inherit SOA NS TTL;

          inherit (githubPages) A AAAA;

          subdomains = {

          };
        }
        mailcow
      ];
    };
  dnszones.dnssecEnabled = [ "milfmail.net" ];
}
