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
    logo = utils.sgdb "logo" 139152 "sha256-4rJkS7j19VNjdqJ/aWLWPMKRc33TBgqUQZF7kKU6Vgk=";
    poster = utils.sgdb "grid" 627852 "sha256-x+fjJAdg4u3PoRm24GKGlNcTEpUXrIRe7y+rtDRr/cU=";
    screenshot = [
      (utils.sgdb "hero" 143488 "sha256-bukgoZzUFWgycsqvMM4Gh3Irx6w1oLZ/cGiZt8k8+XM=")
      (utils.dl "https://web.archive.org/web/20261006103834id_/https://i.ytimg.com/vi/AO17_ao7wu0/maxresdefault.jpg" "1w16jgihy2bj9dxvmyslphik66rzmp4qv7qy4j09q7vzii7n0pdz") # from https://youtu.be/AO17_ao7wu0
    ];
  };
  developer = "LanPiaoPiao";
  genres = [ "Strategy" ];
}
