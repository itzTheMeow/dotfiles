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

  # dolphin resolves the TerminalService desktop file via KDesktopFile, which
  # only looks in XDG_DATA_HOME (~/.local/share/applications) and nowhere else
  # (KDE bug 501435), so "Open Terminal Here" has no icon unless kitty's entry
  # exists there.
  #TODO:26.11 check this
  # TODO: remove once nixpkgs ships dolphin 26.08+ (KService-based lookup)
  xdg.dataFile."applications/kitty.desktop".source = "${pkgs.kitty}/share/applications/kitty.desktop";

  catppuccin.kitty.enable = true;
}
