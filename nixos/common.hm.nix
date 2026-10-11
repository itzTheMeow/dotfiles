{ xelib, ... }: {
  home.stateVersion = "25.11"; # not to be changed
  #TODO:pr https://github.com/nix-community/home-manager/pull/8865 i insist - this can be disabled once merged
  home.enableNixpkgsReleaseCheck = false;
  programs.home-manager.enable = true; # manage itself

  # catppuccin settings
  catppuccin = {
    enable = true;
    autoEnable = false;
    inherit (xelib.globals.catppuccin) accent flavor;
  };
}
