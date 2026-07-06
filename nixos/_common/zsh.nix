{ host, pkgs, ... }:
{
  home-manager.importAll = [ ./zsh.hm.nix ];

  programs.bash.enable = true;
  programs.zsh.enable = true;

  # set as default shell
  users.users.root.shell = pkgs.zsh;
  users.users.${host.username}.shell = pkgs.zsh;

  # persist the zsh_history directory
  persist.ed.home.userDirectories = [ ".local/share/zsh_history" ];
  persist.ed.persist.directories = [ "/etc/atuin/data" ];

  systemd.tmpfiles.rules = [ "d /etc/atuin/data 0755 xela xela - -" ];
  programs.atuin = {
    enable = true;
    daemon.enable = true;
    settings = {
      #  auto_sync = true;
      #  sync_frequency = "5m";
      #  sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
    };
  };
}
