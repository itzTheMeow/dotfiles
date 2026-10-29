{ ... }: {
  home-manager.importUser = [
    (_: {
      programs.element-desktop = {
        enable = true;
      };
      catppuccin.element-desktop.enable = true;
    })
  ];

  persist.ed.home.userDirectories = [ ".config/Element" ];
}
