{
  host,
  pkgs,
  xelpkgs,
  ...
}@inputs:
let
  dir = builtins.readDir ./.;
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
      package = xelpkgs.pegasus-frontend;
      theme = {
        package = xelpkgs.pegasus-theme-gameos-fire-skye;
        settings = {
          "Allow video thumbnails" = "No";
          "Always show titles" = "No";
          "Blur Background" = "Yes";
          "Collection 1 - Thumbnail" = "Tall";
          "Collection 1" = "Recently Launched";
          "Collection 2 - Thumbnail" = "Tall";
          "Collection 2" = "Favorites";
          "Collection 3 - Thumbnail" = "Tall";
          "Collection 3" = "Most Time Spent";
          "Collection 4 - Thumbnail" = "Tall";
          "Collection 4" = "Randomly Picked";
          "Default to full details" = "Yes";
          "Enable mouse hover" = "No";
          "Game Background" = "Screenshot";
          "Game Logo" = "Show";
          "Hide button help" = "Yes";
          "Randomize Background" = "Yes";
          "Show scanlines" = "No";
          "Use posters for grid" = "Yes";
          "Video preview" = "No";
        };
      };
      enableProviders = [
        "pegasus_media"
        "steam"
      ];
      gameDirs = [ "/home/xela/tmp" ];

      collections."PC" = {
        shortname = "nix";
      };
      games = map (name: import ./${name}/default.nix inputs) (
        builtins.filter (name: dir.${name} == "directory") (builtins.attrNames dir)
      );
    };
  };
}
