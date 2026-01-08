{ pkgs, ... }:
{
  home.packages = [ pkgs.thunderbird ];
  catppuccin.thunderbird.enable = true;
}
