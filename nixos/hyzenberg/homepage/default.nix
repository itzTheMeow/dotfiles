{
  config,
  lib,
  ...
}:
let
  app = config.apps.homepage;

  mkService = name: icon: description: domain: {
    ${name} = {
      icon = "${icon}.png";
      href = "https://${domain}";
      inherit description;
      ping = domain;
    };
  };
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

    services = [
      {
        Information = [
          (mkService "ntfy" "ntfy" "Notifications" "ntfy.xela.codes")
        ];
      }
      {
        Downloads = [
          (mkService "Sonarr" "sonarr" "TV Shows" "sonarr.xela")
          (mkService "Radarr" "radarr" "Movies" "radarr.xela")
          (mkService "Prowlarr" "prowlarr" "Indexer Manager" "prowlarr.xela")
          (mkService "NZBGet" "nzbget" "Download Client" "nzbget.xela")
        ];
      }
      {
        Storage = [
          (mkService "Forgejo" "forgejo" "Software Forge" "forge.xela.codes")
          (mkService "Immich" "immich" "Photo Organizer" "immich.xela")
          (mkService "Linkwarden" "linkwarden" "Bookmark Manager" "linkwarden.xela")
          (mkService "Paperless" "paperless-ngx" "Document Store" "paperless.xela")
        ];
      }
      {
        Sysadmin = [
          (mkService "Beszel" "beszel" "System Monitoring" "beszel.xela")
          (mkService "Headplane" "headplane" "Headscale Admin" "headplane.xela")
          (mkService "Pocket ID" "pocket-id" "OIDC Provider" "auth.xela.codes")
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
