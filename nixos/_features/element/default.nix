{ ... }: {
  home-manager.importUser = [
    (_: {
      programs.element-desktop = {
        enable = true;
      };
      catppuccin.element-desktop = true;
    })
  ];

  persist.ed.home.userDirectories = [ ".config/Element" ];
}
