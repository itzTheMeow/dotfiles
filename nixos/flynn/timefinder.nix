{
  config,
  host,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    (pkgs.timefinder-electron.override {
      extraEnv = {
        TIMEFINDER_BEARER_TOKEN_FILE = config.sops.secrets.timefinder-electron.path;
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
