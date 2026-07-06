# for the flixur demo site and stuff
{
  dns,
  pkgs,
  xelib,
  ...
}:
let
  domain = "flixur.app";

  website = pkgs.callPackage ./website.package.nix { };
in
{
  dnszones.list.${domain} =
    with dns.lib.combinators;
    with xelib.dns;
    {
      inherit SOA NS TTL;

      subdomains = {
        www.CNAME = [ (cname (fqdn "flixurapp.github.io")) ];
        try.CNAME = [ (cname "hyzen.xela.codes.") ];
        "_github-challenge-flixurapp-org".TXT = [ (txt "3404e86f6c") ];
      };
    }
    // (pointHost hostname);
  dnszones.dnssecEnabled = [ domain ];

  # serve static site
  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    root = "${website}";
  };
}
