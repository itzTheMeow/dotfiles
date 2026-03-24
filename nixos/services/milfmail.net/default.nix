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
{
  dnszones.list =
    with dns.lib.combinators;
    with xelib.dns;
    {
      ${domain} = lib.mkMerge [
        { inherit SOA NS TTL; }
        (dns.pointHost hostname)
        (mailcow {
          dkimKey = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqJildZaRmkd3730rfJmTgybr7slKMdqwj20xFh1HDYFN5mEe1Qg6kbKzD+cD0/4Z8ZloIAvonwESA6164pGQyFhG5+dvEqrjc1GdHbQgsygIx7INuY4yqwz0L3/5g4gt2C+wklf6IqLh8v80LMWvJn6Z6TGfMj6K6QwF3NSod91h7e9L0aoGind35zHjDTaMAFtva+Xwgf2OCLDlrynosOR8lsrcCTJpD8z8jgfsykmMOu8eE6JvOzUWg7SJMX2aowTLFaPWS7uo0pJWfuGAWZ/Ru2BmEqk6YLQm/MnbaCTCp7nEqyRQP9ga6uNtkpr3m/ucOWI+Wo0u/ZfRMM4+EQIDAQAB";
        })
      ];
    };
  dnszones.dnssecEnabled = [ domain ];

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/".return = "301 https://${xelib.mail.domain}$request_uri";
  };
}
