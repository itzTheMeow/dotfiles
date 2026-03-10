# kde specific settings
{ pkgs, xelib, ... }:
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

  environment.systemPackages = with pkgs; [
    # kde system utils
    kdePackages.kate
    kdePackages.kdenlive
    kdePackages.krfb
    kdePackages.partitionmanager
    kdePackages.plasma-browser-integration

    # desktop theme
    (catppuccin-kde.override {
      flavour = [ xelib.globals.catppuccin.flavor ];
      accents = [ xelib.globals.catppuccin.accent ];
      winDecStyles = [ "classic" ];
    })
  ];

  # VNC server on Tailscale
  systemd.user.services.krfb = {
    description = "KDE Remote Frame Buffer (VNC Server)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    environment = {
      DISPLAY = ":0";
    };
    serviceConfig = {
      ExecStart = "${pkgs.kdePackages.krfb}/bin/krfb --nodialog";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
