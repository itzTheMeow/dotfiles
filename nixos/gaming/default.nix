{
  host,
  pkgs,
  xelpkgs,
  ...
}:
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
          "Randomize Background" = "Screenshot";
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
      games = [
        {
          title = "Hell's Kitchen: The Game";
          collections = [ "PC" ];
          files = [ "${xelpkgs.game-hells-kitchen}/bin/hells-kitchen" ];
          favorite = true;
          assets = {
            logo =
              pkgs.runCommand "hells-kitchen-logo.png" { nativeBuildInputs = [ pkgs.imagemagick ]; }
                # extract the 128x128 layer from the ico
                ''convert "${xelpkgs.game-hells-kitchen}/Icon.ico[2]" -background none -gravity center -extent 192x192 "$out"'';
            poster = pkgs.fetchurl {
              url = "https://web.archive.org/web/20260303202555if_/https://cdn2.steamgriddb.com/thumb/2027fe96f39a43c255e3a9a4fae8c727.jpg";
              name = "";
              sha256 = "sha256-BW+wtFZsF2BlW8cJm7k+29UuEcxMjbANx2udsaXHSPM=";
            };
            # https://web.archive.org/web/20260303203009if_/https://cdn2.steamgriddb.com/hero_thumb/410525841bbf485b7c29db7db4da9b18.jpg
            screenshot = [
              (pkgs.fetchurl {
                url = "https://web.archive.org/web/20260303014312if_/https://screens.16bit.pl/hells-kitchen-the-game/4.jpg";
                sha256 = "sha256-9dbgsdzloJ0/H+9o9gwsMl7of7HnWRYA3mOqu/w9zuo=";
              })
            ];
          };
        }
      ];
    };
  };
}
