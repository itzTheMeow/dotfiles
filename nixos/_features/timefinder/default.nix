# to enable this has to have a relay set up somewhere as an app
{
  config,
  host,
  hostname,
  pkgs,
  xelib,
  ...
}:
let
  app = xelib.apps."timefinder-electron-relay-${hostname}";
in
{
  environment.systemPackages = [
    (pkgs.timefinder-electron.override {
      extraEnv = {
        TIMEFINDER_BEARER_TOKEN_FILE = config.sops.groupPaths.timefinder-electron.token;
        TIMEFINDER_SERVER_HOST = host.ip;
        TIMEFINDER_SERVER_PORT = app.portString;
        TIMEFINDER_WEBHOOK_BASE = app.url;
        TIMEFINDER_SCHEDULE_START = "09:00";
        TIMEFINDER_SCHEDULE_END = "06:00";
      };
    })
  ];

  sops.groups.timefinder-electron.token = {
    value = "op://Private/4vy5vcmy3j7xaopmrv3ldmpama/API Keys/TimeFinder Electron";
    owner = host.username;
  };
}
