{ pkgs, xelpkgs, ... }:
let
  pkg = pkgs.callPackage ./pkg.nix { inherit xelpkgs; };
in
{
  title = "Plants vs. Zombies: Fusion";
  collections = [ "PC" ];
  files = [ "${pkg}/bin/pvz-fusion" ];
  favorite = true;
  assets = {
    logo = ./logo.webp;
    poster = ./poster.webp;
    screenshot = [
      ./screenshot1.webp
      ./screenshot2.webp
    ];
  };
  developers = [ "LanPiaoPiao" ];
  genres = [ "Strategy" ];
}
