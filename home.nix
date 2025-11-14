{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      home-manager
      rustic
      nixfmt-rfc-style
    ];

    username = "meow";
    homeDirectory = "/home/meow";

    stateVersion = "23.11";
  };
}