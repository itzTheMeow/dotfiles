{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.siyuan ];

  persist.ed.home.userDirectories = [
    ".config/siyuan" # app settings
    ".config/SiYuan-Electron" # electron data
    ".local/share/siyuan-data" # actual workspace data
  ];
}
