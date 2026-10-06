{ pkgs, utils, ... }:
let
  pkg = pkgs.prismlauncher;
in
{
  slug = "minecraft";
  title = "Minecraft (Prism Launcher)";
  collections = [ "PC" ];
  files = [ "${pkg}/bin/prismlauncher" ];
  favorite = true;
  assets = {
    logo = utils.sgdb "logo" 55758 "sha256-l1dutFU56CfeJV6P6BNBh53LSsxUXuSgoX5r51Y1dh0=";
    poster = utils.sgdb "grid" 36537 "sha256-UZ77kc4lnmFFEY1akV4d1Y/sB773HJSk8LY4bPetZTs=";
    screenshot = [
      (utils.sgdb "hero" 40302 "sha256-BVF993EVguA7jmNTkyswqmnTZZy2MaW3JEyg5W1hC6o=")
      (utils.sgdb "hero" 14757 "sha256-AmEY6mchhGyHs/la9TOBIsOqAeHEMlLHs9Nk8OdLyoQ=")
    ];
  };
  developer = "Mojang";
  genres = [ "Sandbox" ];
}
