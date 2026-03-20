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
      QT_QPA_PLATFORM = "wayland";
    };
    serviceConfig = {
      ExecStart = "${pkgs.kdePackages.krfb}/bin/krfb --nodialog";
      Restart = "on-failure";
      RestartSec = "5s";
      BusName = "org.kde.krfb";
    };
  };
  systemd.user.services.flatpak-krfb-permissions = {
    description = "Authorize KRFB for Remote Desktop";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = [ pkgs.flatpak ];
    # authorize the krfb service to connect to the desktop
    # https://develop.kde.org/docs/administration/portal-permissions/
    script = ''
      flatpak permission-set kde-authorized remote-desktop org.kde.krfb yes
      echo "Authorized."
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
