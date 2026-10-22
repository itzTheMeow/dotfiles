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
  imports = [ ./apt-mirror.nix ];

  services.nginx.virtualHosts."${subdomain}.${xelib.domain}" = {
    addSSL = true;
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
