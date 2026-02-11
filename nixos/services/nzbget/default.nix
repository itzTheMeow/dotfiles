{ xelib, lib, ... }:
let
  svc = xelib.services.nzbget;
  ControlIP = xelib.hosts.${svc.host}.ip;
in
lib.mkMerge [
  {
    # shared download directory
    systemd.tmpfiles.rules = [
      "d /home/downloads 0777 nzbget nzbget -"
    ];

    services.nzbget = {
      enable = true;
      settings = {
        MainDir = "/var/lib/nzbget";
        DestDir = "/home/downloads";

        inherit ControlIP;
        ControlPort = svc.port;
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
  }
  (xelib.mkNginxProxy svc.domain "http://${ControlIP}:${toString svc.port}" { })
]
