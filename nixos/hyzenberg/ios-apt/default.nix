{
  hostname,
  pkgs,
  xelib,
  ...
}:
let
  ios-apt = pkgs.callPackage ./package.nix { };
  subdomain = "apt";
in
{
  services.nginx.virtualHosts."${subdomain}.${xelib.domain}" = {
    forceSSL = true;
    enableACME = true;
    root = "${ios-apt}";
    # enable file index and 404 page
    locations."/".extraConfig = ''
      autoindex on;
      error_page 404 /404.html;
    '';
  };

  dnszones.list.${xelib.domain}.subdomains.apt = with xelib.dns; pointHost hostname;
}
