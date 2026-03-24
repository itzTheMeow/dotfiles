{ pkgs, xelpkgs, ... }:
let
  pkg = pkgs.callPackage ./pkg.nix { inherit xelpkgs; };
in
{
  title = "Hell's Kitchen: The Game";
  collections = [ "PC" ];
  files = [ "${pkg}/bin/hells-kitchen" ];
  favorite = true;
  assets = {
    logo =
      pkgs.runCommand "hells-kitchen-logo.png" { nativeBuildInputs = [ pkgs.imagemagick ]; }
        # extract the 128x128 layer from the ico
        ''convert "${pkg}/Icon.ico[2]" -background none -gravity center -extent 192x192 "$out"'';
    poster = ./poster.webp;
    screenshot = [
      ./screenshot1.webp
      ./screenshot2.webp
    ];
  };
}
