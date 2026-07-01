{ config, ... }:
let
  app = config.apps.jellyfin;
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
}
