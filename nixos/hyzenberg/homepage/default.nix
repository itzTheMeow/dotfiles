{
  config,
  xelib,
  ...
}:
let
  app = config.apps.homepage;
in
{
  imports = [ ./background.nix ];

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
      cardBlur = "md";
      headerStyle = "clean";
      target = "_top";
      theme = "dark";
      color = "stone";
      useEqualHeights = true;
      layout = {
        Information = {
          style = "row";
          columns = 4;
        };
        Media = {
          style = "row";
          columns = 4;
        };
        Downloads = {
          style = "row";
          columns = 5;
        };
        Sysadmin = {
          style = "row";
          columns = 5;
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
            };
          };
      in
      [
        {
          Information = [
            (srv "degoog")
            (srv "open-webui")
            (srv "freshrss")
            (srv "ntfy")
          ];
        }
        {
          Media = [
            (srv "copyparty")
            (srv "plex")
            (srv "jellyfin")
            (srv "forgejo")
            (srv "immich")
            (srv "mealie")
            (srv "linkwarden")
            (srv "paperless")
          ];
        }
        {
          Downloads = [
            (srv "ytmusic")
            (srv "sonarr")
            (srv "radarr")
            (srv "prowlarr")
            (srv "nzbget")
          ];
        }
        {
          Sysadmin = [
            (srv "beszel")
            (srv "syncthing-relay")
            (srv "tautulli")
            (srv "headplane")
            (srv "pocket-id")
          ];
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
}
