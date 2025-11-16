{ pkgs, ... }:
{
  home.packages = [ (pkgs.callPackage ./patch.nix { inherit pkgs; }) ];
}
