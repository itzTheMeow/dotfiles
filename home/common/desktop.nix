{ pkgs, ... }:
{
  imports = [
    ../programs/kitty
  ];

  home = {
    packages = with pkgs; [
      # fonts
      nerd-fonts.caskaydia-mono
      corefonts
    ];
  };
  fonts.fontconfig.enable = true;
}
