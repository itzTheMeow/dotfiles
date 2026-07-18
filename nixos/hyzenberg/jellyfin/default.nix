{ config, xelib, ... }:
let
  app = config.apps.jellyfin;
  splitPublicDomain = xelib.dns.splitDomain app.details.publicDomain;
in
{
  apps.jellyfin = {
    domain = "jellyfin.xela";
    port = 8096;
    enableProxy = true;
    details = {
      #TODO: public domain
      publicDomain = "fin.xela.codes";
    };
    allowedHosts = [ "brayden" ];

    description = "Movies & TV";
  };

  services.jellyfin = {
    enable = true;
  };
  # needs to be in the media center group
  users.users.jellyfin.extraGroups = [ "mediacenter" ];

  # public-facing domain
  nginx.proxy.${app.details.publicDomain} = {
    target.port = app.port;
    oidcGroups = [ "jellyfin_public" ];
  };
  dnszones.list."${splitPublicDomain.domain}".subdomains."${splitPublicDomain.subdomain}" =
    xelib.dns.pointHost app.host;
}
