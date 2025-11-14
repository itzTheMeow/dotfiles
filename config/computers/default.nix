{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      nixfmt-rfc-style
      nixd

      # fonts
      nerd-fonts.caskaydia-mono
    ];
  };
  fonts.fontconfig.enable = true;

  programs = {
    kitty = {
      enable = true;
      font.name = "CaskaydiaMono NFM";
      keybindings = {
        "f5" = "load_config_file";
        "ctrl+w" = "quit";
      };
      settings = {
        editor = "nano";
        tab_bar_min_tabs = 1;
        tab_bar_style = "slant";
      };
      shellIntegration = {
        mode = "no-cursor";
        enableBashIntegration = true;
        enableZshIntegration = true;
      };
      themeFile = "Catppuccin-Mocha";
    };
  };
}
