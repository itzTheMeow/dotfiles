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
        TIMEFINDER_BEARER_TOKEN_FILE = config.sops.secrets.timefinder-electron.path;
        TIMEFINDER_SERVER_HOST = host.ip;
        TIMEFINDER_SERVER_PORT = app.portString;
        TIMEFINDER_WEBHOOK_BASE = app.url;
      };
    })
  ];

  sops.secrets.timefinder-electron = {
    sopsFile = config.sops.opSecrets.timefinder-electron.fullPath;
    key = "bearer";
    owner = host.username;
  };
  sops.opSecrets.timefinder-electron.keys.bearer =
    "op://Private/4vy5vcmy3j7xaopmrv3ldmpama/API Keys/TimeFinder Electron";
}
