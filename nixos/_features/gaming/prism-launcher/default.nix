{ pkgs, ... }:
let
  pkg = pkgs.prismlauncher;
in
{
  title = "Minecraft (Prism Launcher)";
  collections = [ "PC" ];
  files = [ "${pkg}/bin/prismlauncher" ];
  favorite = true;
  assets = {
    logo = ./logo.webp;
    poster = ./poster.webp;
    screenshot = [
      ./screenshot1.webp
      ./screenshot2.webp
    ];
  };
  developer = "Mojang";
  genres = [ "Sandbox" ];
}
