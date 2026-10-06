{ pkgs, xelib, ... }:
{
  programs.kitty = {
    enable = true;
    font.name = xelib.globals.fonts.terminal.name;
    keybindings = {
      "f5" = "load_config_file";
      "ctrl+w" = "quit";
    };
    settings = {
      shell = "${pkgs.zsh}/bin/zsh --login --interactive";

      editor = "nano";
      scrollback_lines = 5000;
      startup_session = toString (
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

  # open kitty/ncdu here actions
  xdg.dataFile =
    xelib.mkDolphinContextAction {
      name = "kitty-open-here";
      action = "openKittyHere";
      menuName = "Open Kitty Here";
      icon = "${pkgs.kitty}/share/icons/hicolor/scalable/apps/kitty.svg";
      tryExec = "kitty";
      exec = "kitty --directory %f";
    }
    // xelib.mkDolphinContextAction {
      name = "ncdu-open-here";
      action = "openNcduHere";
      menuName = "Open ncdu Here";
      icon = "disk-usage-analyzer";
      tryExec = "kitty";
      exec = "kitty --directory %f ncdu";
    };

  catppuccin.kitty.enable = true;
}
