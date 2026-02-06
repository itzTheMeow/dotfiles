{ xelib, lib, ... }:
let
  svc = xelib.services.nzbget;
  ControlIP = xelib.hosts.${svc.host}.ip;
in
lib.mkMerge [
  {
    services.nzbget = {
      enable = true;
      settings = {
        MainDir = "/var/lib/nzbget";
        # might not need these
        /*
          DestDir = "/var/lib/nzbget/completed";
          InterDir = "/var/lib/nzbget/intermediate";
          NzbDir = "/var/lib/nzbget/nzb";
          QueueDir = "/var/lib/nzbget/queue";
          TempDir = "/var/lib/nzbget/tmp";
          ScriptDir = "/var/lib/nzbget/scripts";
          WebDir = "/var/lib/nzbget/webui";
          LogFile = "/var/lib/nzbget/nzbget.log";
        */

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
  (xelib.mkNginxProxy "nzbget.xela" "http://${ControlIP}:${toString svc.port}" { })
]
