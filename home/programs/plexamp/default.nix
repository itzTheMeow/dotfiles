{ pkgs, ... }:
{
  home.packages = [
    (import ./patch.nix { inherit pkgs; })
  ];
}
