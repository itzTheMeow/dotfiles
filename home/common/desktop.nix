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
      montserrat
    ];
  };
  fonts.fontconfig.enable = true;
}
