{
  pkgs,
  utils,
  xelpkgs,
  ...
}:
let
  pkg = pkgs.callPackage ./package.nix { inherit xelpkgs; };
in
{
  slug = "hells-kitchen-the-game";
  title = "Hell's Kitchen: The Game";
  collections = [ "PC" ];
  files = [ "${pkg}/bin/hells-kitchen" ];
  assets = {
    logo =
      pkgs.runCommand "hells-kitchen-logo.png" { nativeBuildInputs = [ pkgs.imagemagick ]; }
        # extract the 128x128 layer from the ico
        ''convert "${pkg}/Icon.ico[2]" -background none -gravity center -extent 192x192 "$out"'';
    poster = utils.sgdb "grid" 379431 "sha256-jmJcLWci97CkTACTvjMo9gCy8mk1WJ0W3pCc4fjcytI=";
    screenshot = [
      # literally the only decent screenshots i could find
      (utils.dl "https://web.archive.org/web/20261006095716id_/https://www.myabandonware.com/media/screenshots/h/hell-s-kitchen-the-game-orl/hell-s-kitchen-the-game_3.png" "1mzsn9bfmqvisx0k3nq6bqpjsb6gf6ysxr8v9c2w4dv9193ln7vy")
      (utils.dl "https://web.archive.org/web/20261006095953id_/https://www.myabandonware.com/media/screenshots/h/hell-s-kitchen-the-game-orl/hell-s-kitchen-the-game_4.png" "0zcj95q5vissd5likaainqcfmsm7hlbc72k9b8hl5wh5m160dhhz")
    ];
  };
  developer = "Ludia";
  genres = [
    "Strategy"
    "Cooking"
  ];
}
