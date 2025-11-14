{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      # base stuff
      home-manager
      nixfmt-rfc-style
      nixd

      rustic
      ncdu
    ];

    username = "meow";
    homeDirectory = "/home/meow";

    stateVersion = "23.11"; # not to be changed
  };
}
