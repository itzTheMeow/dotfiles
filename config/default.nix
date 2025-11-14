{ pkgs, ... }:
{
  home = {
    stateVersion = "23.11"; # not to be changed

    packages = with pkgs; [
      # obviously needed
      home-manager

      rustic
      ncdu
    ];
  };
}
