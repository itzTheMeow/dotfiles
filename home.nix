{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      home-manager
#      nixfmt-rfc-style
    ];

    username = "meow";
    homeDirectory = "/home/meow";

    stateVersion = "23.11";
  };
}