{ pkgs, ... }:
{
  imports = [
    ../programs/kitty
  ];

  home = {
    packages = with pkgs; [
      # fonts
      nerd-fonts.caskaydia-mono
    ];
  };
  fonts.fontconfig.enable = true;
}
