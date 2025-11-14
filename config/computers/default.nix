{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      nixfmt-rfc-style
      nixd

      # fonts
      nerd-fonts.caskaydia-mono

      # tools
      immich-cli
    ];

    file = {
      ".config/1Password/ssh/agent.toml".text = ''
        [[ssh-keys]]
        vault = "Private"
        [[ssh-keys]]
        vault = "NVSTly"
        [[ssh-keys]]
        vault = "NVSTly Internal"
      '';
    };
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
      shellIntegration.mode = "no-cursor";
      themeFile = "Catppuccin-Mocha";
    };
  };
}
