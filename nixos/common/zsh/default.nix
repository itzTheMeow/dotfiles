{ host, pkgs, ... }:
{
  home-manager.importAll = [ ./zsh.hm.nix ];

  programs.zsh.enable = true;

  # set as default shell
  users.users.root.shell = pkgs.zsh;
  users.users.${host.username}.shell = pkgs.zsh;

  # persist the zsh_history directory
  persist.ed.home.userDirectories = [ ".local/share/zsh_history" ];
}
