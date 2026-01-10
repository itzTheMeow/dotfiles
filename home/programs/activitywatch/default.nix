{ pkgs, ... }:
{
  services.activitywatch = {
    enable = true;
    watchers = {
      aw-qt = {
        package = pkgs.activitywatch;
      };
      aw-sync = {
        package = pkgs.activitywatch;
      };
      aw-watcher-afk = {
        package = pkgs.activitywatch;
      };
      aw-watcher-window = {
        package = pkgs.activitywatch;
      };
    };
  };

  xdg.configFile."activitywatch/aw-server/settings.json" = {
    source = ./settings.json;
  };
}
