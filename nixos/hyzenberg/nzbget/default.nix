{
  config,
  ...
}:
let
  app = config.apps.nzbget;
in
{
  apps.nzbget = {
    domain = "nzbget.xela";
    port = 58815;
    enableProxy = true;

    name = "NZBGet";
    description = "Download Client";
  };

  # shared download directory
  systemd.tmpfiles.rules = [
    "d /home/downloads 0777 nzbget nzbget -"
  ];

  services.nzbget = {
    enable = true;
    settings = {
      MainDir = "/var/lib/nzbget";
      DestDir = "/home/downloads";

      ControlIP = app.ip;
      ControlPort = app.port;
      ControlUsername = "nzbget";

      # other settings
      ArticleCache = 100;
      WriteBuffer = 1024;
      DiskSpace = 10240;
      KeepHistory = 7;
      ParBuffer = 100;
      DirectRename = "yes";
      DirectUnpack = "yes";
    };
  };
  systemd.services.nzbget.after = [ "tailscale-online.service" ];

  # radar and sonarr need access to nzbget
  nginx.proxy.${app.domain}.allowedAppHosts = [
    "radarr"
    "sonarr"
  ];
}
