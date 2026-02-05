{ pkgs, xelib, ... }:
let
  sshConfig = import ../../common/ssh.nix { inherit pkgs xelib; };
in
{
  programs.kitty = {
    enable = true;
    font.name = "CaskaydiaMono NFM";
    keybindings = {
      "f5" = "load_config_file";
      "ctrl+w" = "quit";
    };
    settings = {
      shell = "${pkgs.zsh}/bin/zsh --login --interactive";

      editor = "nano";
      scrollback_lines = 5000;
      startup_session = "./sessions/default.conf";
      tab_bar_min_tabs = 1;
      tab_bar_style = "slant";
    };
    shellIntegration.mode = "no-cursor";
  };
  catppuccin.kitty.enable = true;

  # config profiles
  xdg.configFile."kitty/sessions/default.conf".text = ''
    focus
    focus_os_window
    os_window_state maximized
    launch
  '';
  home.file = sshConfig.kittySessions;
}
