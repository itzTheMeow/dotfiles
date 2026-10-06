{ pkgs, xelib, ... }: {
  environment.systemPackages = [ pkgs.ncdu ];

  home-manager.importUser = [
    (_: {
      xdg.configFile."ncdu/config".text = "--exclude pCloudDrive";
      xdg.dataFile = xelib.mkDolphinContextAction {
        name = "ncdu-open-here";
        action = "openNcduHere";
        menuName = "Open ncdu Here";
        icon = "disk-usage-analyzer";
        tryExec = "kitty";
        exec = "kitty --directory %f ncdu";
      };
    })
  ];
}
