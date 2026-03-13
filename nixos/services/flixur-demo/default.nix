# for the flixur demo site and stuff
{ dns, xelib, ... }:
let
  svcHost = "hyzenberg";
in
{
  dnszones.list =
    with dns.lib.combinators;
    with xelib.dns;
    {
      "flixur.app" = {
        inherit SOA NS;

        inherit (githubPages) A AAAA;

        subdomains = {
          www = githubPages;
          try.CNAME = [ (cname "hyzen.xela.codes.") ];
          "_github-challenge-flixurapp-org".TXT = [ (txt "3404e86f6c") ];
        };
      };
    };
  dnszones.dnssecEnabled = [ "flixur.app" ];

  services.nginx.virtualHosts."www.flixur.app" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      return = "301 https://flixur.app$request_uri";
    };
  };
}
