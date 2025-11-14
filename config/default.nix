{ pkgs, ... }:
let
  shellAliases = { };
in
{
  home = {
    stateVersion = "23.11"; # not to be changed

    packages = with pkgs; [
      # obviously needed
      home-manager

      ncdu
      rclone
      rustic
    ];
  };

  programs = {
    bash = {
      enable = true;
      bashrcExtra = "source ~/.profile_extra";
      inherit shellAliases;
    };
    zsh = {
      enable = true;
      inherit shellAliases;
    };
  };
}
