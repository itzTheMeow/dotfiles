# kde specific settings
{ pkgs, ... }:
{
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };

  # portal settings
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common.default = "kde";
  };
}
