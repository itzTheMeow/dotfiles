{ pkgs, ... }:
let
  shellAliases = {
    nixup = ''
      current_flake=$(nixup_currentflake)
      home-manager switch --flake ~/.dotfiles#$current_flake
    '';
  };
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

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
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
