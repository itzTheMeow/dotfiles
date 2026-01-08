{ pkgs, ... }:
{
  home.packages = [ pkgs.vesktop ];
  catppuccin.vesktop.enable = true;
}
