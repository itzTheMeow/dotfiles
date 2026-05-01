{
  config,
  lib,
  xelib,
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
          (mkService "FreshRSS" "freshrss" "RSS Reader" xelib.apps.freshrss.url)
          (mkService "ntfy" "ntfy" "Notifications" xelib.apps.ntfy.url)
        ];
      }
      {
        Downloads = [
          (mkService "Sonarr" "sonarr" "TV Shows" xelib.apps.sonarr.url)
          (mkService "Radarr" "radarr" "Movies" xelib.apps.radarr.url)
          (mkService "Prowlarr" "prowlarr" "Indexer Manager" xelib.apps.prowlarr.url)
          (mkService "NZBGet" "nzbget" "Download Client" xelib.apps.nzbget.url)
        ];
      }
      {
        Storage = [
          (mkService "Forgejo" "forgejo" "Software Forge" xelib.apps.forgejo.url)
          (mkService "Immich" "immich" "Photo Organizer" xelib.apps.immich.url)
          (mkService "Linkwarden" "linkwarden" "Bookmark Manager" xelib.apps.linkwarden.url)
          (mkService "Paperless" "paperless-ngx" "Document Store" "paperless.xela")
        ];
      }
      {
        Sysadmin = [
          (mkService "Beszel" "beszel" "System Monitoring" xelib.apps.beszel.url)
          (mkService "Headplane" "headplane" "Headscale Admin" xelib.apps.headplane.url)
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
