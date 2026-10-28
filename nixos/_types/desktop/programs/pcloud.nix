{ host, pkgs, ... }: {
  environment.systemPackages = [ pkgs.pcloud ];

  persist.ed.home.userDirectories = [
    ".config/pcloud"
    ".pcloud"
  ];

  home-manager.importUser = [
    (_: {
      # start with system
      xdg.autostart.entries = [ "${pkgs.pcloud}/share/applications/pcloud.desktop" ];
      # make ncdu ignore pcloud
      xdg.configFile."ncdu/config".text = "--exclude pCloudDrive";
      # make baloo ignore pcloud mount
      programs.plasma.configFile."baloofilerc"."General"."exclude folders" =
        "/home/${host.username}/pCloudDrive";
    })
  ];
}
