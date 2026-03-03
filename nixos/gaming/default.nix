{
  host,
  pkgs,
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
    programs.pegasus-frontend = {
      enable = true;
      theme = {
        package = xelpkgs.pegasus-theme-gameos-fire-skye;
        settings = {
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
      };
      enableProviders = [
        "pegasus_media"
        "steam"
      ];
      favorites = [ "steam:960090" ];
    };
  };

  environment.systemPackages = [
    xelpkgs.game-hells-kitchen
  ];
}
