{ dns, xelib, ... }:
{
  dnszones.list =
    with dns.lib.combinators;
    with xelib.dns;
    {
      "milfmail.net" = {
        inherit SOA NS TTL;

        inherit (githubPages) A AAAA;

        subdomains = {

        };
      };
    };
  dnszones.dnssecEnabled = [ "milfmail.net" ];
}
