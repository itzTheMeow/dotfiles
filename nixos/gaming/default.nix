{
  host,
  pkgs,
  xelib,
  xelpkgs,
  ...
}:
let
  pegasusTheme = "pegasus-theme-gameos-fire-skye";
in
{
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # steam needs access to the cursor theme
      extraPkgs = _: [
        xelpkgs.colloid-cursors
      ];
    };
  };

  home-manager.users.${host.username} = {
    xdg.configFile = {
      "pegasus-frontend/themes/${pegasusTheme}".source = xelpkgs.${pegasusTheme};
      "pegasus-frontend/settings.txt".text = xelib.toKVCommaString {
        "general.theme" = "themes/${pegasusTheme}/";
        "general.verify-files" = "true";
        "general.input-mouse-support" = "true";
        "general.fullscreen" = "true";
        "providers.pegasus_media.enabled" = "true";
        "providers.steam.enabled" = "true";
        "providers.gog.enabled" = "false";
        "providers.es2.enabled" = "false";
        "providers.logiqx.enabled" = "false";
        "providers.lutris.enabled" = "false";
        "providers.skraper.enabled" = "false";
        "keys.page-up" = "PgUp,GamepadL2";
        "keys.page-down" = "PgDown,GamepadR2";
        "keys.prev-page" = "Q,A,GamepadL1";
        "keys.next-page" = "E,D,GamepadR1";
        "keys.menu" = "F1,GamepadStart";
        "keys.filters" = "F,GamepadY";
        "keys.details" = "I,GamepadX";
        "keys.cancel" = "Esc,Backspace,GamepadB";
        "keys.accept" = "Return,Enter,GamepadA";
      };
      "pegasus-frontend/theme_settings/${pegasusTheme}.json".text = builtins.toJSON {
        "Allow video thumbnails" = "No";
        "Always show titles" = "No";
        "Blur Background" = "Yes";
        "Collection 1" = "Recently Launched";
        "Collection 1 - Thumbnail" = "Tall";
        "Collection 2" = "Favorites";
        "Collection 2 - Thumbnail" = "Tall";
        "Collection 3" = "Most Time Spent";
        "Collection 3 - Thumbnail" = "Tall";
        "Collection 4" = "Randomly Picked";
        "Collection 4 - Thumbnail" = "Tall";
        "Default to full details" = "Yes";
        "Enable mouse hover" = "No";
        "Game Background" = "Screenshot";
        "Game Logo" = "Show";
        "Hide button help" = "Yes";
        "Show scanlines" = "No";
        "Video preview" = "No";
      };
      "pegasus-frontend/favorites.txt".text = ''
        # List of favorites, one path per line
        steam:960090
        steam:3590
      '';
      "pegasus-frontend/game_dirs.txt".text = ''
        /home/xela/tmp
      '';
    };
  };

  environment.systemPackages = [
    xelpkgs.game-hells-kitchen
    pkgs.pegasus-frontend
  ];
}
