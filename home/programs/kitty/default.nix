{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    package = (pkgs.callPackage ./patch.nix { inherit pkgs; });
    font.name = "CaskaydiaMono NFM";
    keybindings = {
      "f5" = "load_config_file";
      "ctrl+w" = "quit";
    };
    settings = {
      shell = "${pkgs.zsh}/bin/zsh --login --interactive";

      editor = "nano";
      scrollback_lines = 5000;
      tab_bar_min_tabs = 1;
      tab_bar_style = "slant";
    };
    shellIntegration.mode = "no-cursor";
  };
  catppuccin.kitty.enable = true;
}
