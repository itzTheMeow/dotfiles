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
  slug = "pvz-fusion";
  title = "Plants vs. Zombies: Fusion";
  collections = [ "PC" ];
  files = [ "${pkg}/bin/pvz-fusion" ];
  favorite = true;
  assets = {
    logo = utils.sgdb "logo" 139152 "";
    poster = utils.sgdb "grid" 627852 "";
    screenshot = [
      (utils.sgdb "hero" 143488 "")
      (utils.dl "https://web.archive.org/web/20261006103834id_/https://i.ytimg.com/vi/AO17_ao7wu0/maxresdefault.jpg" "") # from https://youtu.be/AO17_ao7wu0
    ];
  };
  developer = "LanPiaoPiao";
  genres = [ "Strategy" ];
}
