{
  lib,
  xelib,
  ...
}:
let
  svc = xelib.services.homepage;
  bindIP = xelib.hosts.${svc.host}.ip;

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
  services.homepage-dashboard = {
    enable = true;
    listenPort = svc.port;

    settings = {
      title = svc.domain;
      base = "https://${svc.domain}";
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
        Downloads = [
          (mkService "Sonarr" "sonarr" "TV Shows" "sonarr.xela")
          (mkService "Radarr" "radarr" "Movies" "radarr.xela")
          (mkService "Prowlarr" "prowlarr" "Indexer Manager" "prowlarr.xela")
          (mkService "NZBGet" "nzbget" "Download Client" "nzbget.xela")
        ];
        Other = [
          (mkService "Beszel" "beszel" "System Monitoring" "beszel.xela")
          (mkService "Linkwarden" "linkwarden" "Bookmark Manager" "linkwarden.xela")
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
        "HOMEPAGE_BIND_ADDR=${bindIP}"
        "HOMEPAGE_ALLOWED_HOSTS=${svc.domain}"
      ];
    };
  };

  nginx.proxy.${svc.domain} = {
    target.port = svc.port;
    # we have to serve the background image separately
    extraConfig = cfg: {
      locations."= /background.jpeg" = lib.mkMerge [
        {
          alias = "${./background.jpeg}";
        }
        cfg
      ];
    };
  };
}
