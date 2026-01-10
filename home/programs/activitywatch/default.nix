{ ... }:
{
  services.activitywatch = {
    enable = true;
    watchers = {
      aw-sync = { };
      aw-watcher-afk = { };
      aw-watcher-input = { };
      aw-watcher-window = { };
    };
  };

  xdg.configFile."activitywatch/aw-server/settings.json" = {
    source = ./settings.json;
  };
}
