{ pkgs, ... }:
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
      startup_session = builtins.toString (
        pkgs.writeText "default.conf" ''
          focus
          focus_os_window
          os_window_state maximized
          launch
        ''
      );
      tab_bar_min_tabs = 1;
      tab_bar_style = "slant";
    };
    shellIntegration.mode = "no-cursor";
  };
  catppuccin.kitty.enable = true;
}
