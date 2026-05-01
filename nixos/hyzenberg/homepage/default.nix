{
  config,
  lib,
  xelib,
  ...
}:
let
  app = config.apps.homepage;
in
{
  apps.homepage = {
    domain = "xela.internal";
    port = 50983;
    enableProxy = true;
  };

  services.homepage-dashboard = {
    enable = true;
    listenPort = app.port;

    settings = {
      title = app.domain;
      base = app.url;
      background = {
        image = "/background.jpeg";
        #  blur = "xs";
      };
      cardBlur = "sm";
      headerStyle = "boxed";
      target = "_self";
      theme = "dark";
      color = "stone";
      layout = {
        Media = {
          style = "columns";
        };
      };
    };

    services =
      let
        # quickly create a service based off an app name
        srv =
          appName:
          let
            a = xelib.apps.${appName};
          in
          {
            ${a.name} = {
              icon = "${a.icon}.png";
              inherit (a) description;
              href = a.url;
              ping = a.url;
            };
          };
      in
      [
        {
          Information = [
            (srv "freshrss")
            (srv "ntfy")
          ];
        }
        {
          Downloads = [
            (srv "sonarr")
            (srv "radarr")
            (srv "prowlarr")
            (srv "nzbget")
          ];
        }
        {
          Storage = [
            (srv "forgejo")
            (srv "immich")
            (srv "linkwarden")
            (srv "paperless")
          ];
        }
        {
          Sysadmin = [
            (srv "beszel")
            (srv "headplane")
            (srv "pocket-id")
          ];
        }
      ];

    widgets = [
      {
        search = {
          provider = "google";
          target = "_blank";
        };
      }
    ];
  };

  systemd.services.homepage-dashboard = {
    after = [ "tailscale-online.service" ];
    serviceConfig = {
      Environment = [
        "HOMEPAGE_BIND_ADDR=${app.ip}"
        "HOMEPAGE_ALLOWED_HOSTS=${app.domain}"
      ];
    };
  };

  # we have to serve the background image separately
  nginx.proxy.${app.domain}.extraConfig = cfg: {
    locations."= /background.jpeg" = lib.mkMerge [
      {
        alias = "${./background.jpeg}";
      }
      cfg
    ];
  };
}
