{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.siyuan ];

  # Everything SiYuan writes outside the workspace lives in the home dir:
  #   ~/Siyuan                       the workspace itself (data/ + conf/)
  #   ~/.siyuan                      app metadata (kernel ~/.siyuan/conf.json)
  #   ~/.config/siyuan               workspace selection / electron user data
  #   ~/.config/siyuan.bak           legacy workspace location record
  #   ~/.config/SiYuan-Electron      legacy electron user data
  persist.ed.home.userDirectories = [
    "Siyuan"
    ".siyuan"
    ".config/siyuan"
    ".config/siyuan.bak"
    ".config/SiYuan-Electron"
  ];
}
