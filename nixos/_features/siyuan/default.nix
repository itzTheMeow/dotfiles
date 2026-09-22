{
  host,
  pkgs,
  xelpkgs,
  ...
}:
{
  environment.systemPackages = [ pkgs.siyuan ];

  # 1Password unlock plugin
  environment.variables.SIYUAN_MASTER_PASSWORD_OP = "op://Private/65oqfbkcvggpgjuufzn44pj5ei/password";
  home-manager.users.${host.username}.xdg.dataFile."siyuan-data/data/plugins/siyuan-op-unlock" = {
    source = xelpkgs.siyuan-op-unlock;
    recursive = true;
  };

  persist.ed.home.userDirectories = [
    ".config/siyuan" # app settings
    ".config/SiYuan-Electron" # electron data
    ".local/share/siyuan-data" # actual workspace data
  ];
}
