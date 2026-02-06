{
  xelib,
  lib,
  ...
}:
let
  svc = xelib.services.homepage-dashboard;
  bindIP = xelib.hosts.${svc.host}.ip;
in
lib.mkMerge [
  {
    services.homepage-dashboard = {
      enable = true;
      listenPort = svc.port;

      settings = {
        title = svc.domain;
        base = "https://${svc.domain}";
        headerStyle = "boxed";
        target = "_self";
        color = "violet";
        layout = {
          Media = {
            style = "row";
            columns = 4;
          };
        };
      };

      services = [
        {
          Media = [
            {
              Sonarr = {
                icon = "sonarr.png";
                href = "https://sonarr.xela";
                description = "TV Shows";
                server = "sonarr";
                container = "sonarr";
              };
            }
            {
              Radarr = {
                icon = "radarr.png";
                href = "https://radarr.xela";
                description = "Movies";
                server = "radarr";
                container = "radarr";
              };
            }
            {
              Prowlarr = {
                icon = "prowlarr.png";
                href = "https://prowlarr.xela";
                description = "Indexer Manager";
                server = "prowlarr";
                container = "prowlarr";
              };
            }
            {
              NZBGet = {
                icon = "nzbget.png";
                href = "https://nzbget.xela";
                description = "Download Client";
                server = "nzbget";
                container = "nzbget";
              };
            }
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
        ];
      };
    };
  }
  (xelib.mkNginxProxy svc.domain "http://${bindIP}:${toString svc.port}" { })
]
