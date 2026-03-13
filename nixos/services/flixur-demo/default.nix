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

        A = [ (a addr.${svcHost}) ];

        subdomains = {
          www.CNAME = [ (cname "github.io.") ];
          try.CNAME = [ (cname "hyzen.xela.codes.") ];
          "_github-challenge-flixurapp-org".TXT = [ (txt "3404e86f6c") ];
        };
      };
    };
  dnszones.dnssecEnabled = [ "flixur.app" ];

  services.nginx.virtualHosts."flixur.app" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      return = "301 https://www.flixur.app$request_uri";
    };
  };
}
