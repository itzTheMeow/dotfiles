{ ... }: {
  home-manager.importUser = [
    (_: {
      programs.thunderbird = {
        enable = true;
        profiles.default = {
          isDefault = true;
        };
      };
      catppuccin.thunderbird.enable = true;
    })
  ];

  persist.ed.home.userDirectories = [
    ".thunderbird"
  ];
}
