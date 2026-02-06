{
  xelib,
  lib,
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
lib.mkMerge [
  {
    services.homepage-dashboard = {
      enable = true;
      listenPort = svc.port;

      settings = {
        title = svc.domain;
        base = "https://${svc.domain}";
        background = "/background.jpeg";
        headerStyle = "boxed";
        target = "_self";
        theme = "dark";
        color = "purple";
        layout = {
          Media = {
            style = "columns";
          };
        };
      };

      services = [
        {
          Media = [
            (mkService "Sonarr" "sonarr" "TV Shows" "sonarr.xela")
            (mkService "Radarr" "radarr" "Movies" "radarr.xela")
            (mkService "Prowlarr" "prowlarr" "Indexer Manager" "prowlarr.xela")
            (mkService "NZBGet" "nzbget" "Download Client" "nzbget.xela")
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
  }
  (xelib.mkNginxProxy svc.domain "http://${bindIP}:${toString svc.port}" {
    extraConfig = {
      locations."/background.jpeg" = {
        alias = "${./background.jpeg}";
      };
    };
  })
]
