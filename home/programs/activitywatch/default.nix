{ ... }:
{
  services.activitywatch = {
    enable = true;
    watchers = {
      aw-sync.enable = true;
      aw-watcher-afk.enable = true;
      aw-watcher-input.enable = true;
      aw-watcher-window.enable = true;
    };
  };

  xdg.configFile."activitywatch/aw-server/settings.json" = {
    source = ./settings.json;
  };
}
