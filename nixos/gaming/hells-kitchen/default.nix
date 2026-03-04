{ pkgs, xelpkgs, ... }:
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
    poster = ./poster.webp;
    # https://web.archive.org/web/20260303203009if_/https://cdn2.steamgriddb.com/hero_thumb/410525841bbf485b7c29db7db4da9b18.jpg
    screenshot = [
      ./screenshot1.webp
      ./screenshot2.webp
    ];
  };
}
