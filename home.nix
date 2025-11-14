{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      hello
    ];

    username = "meow";
    homeDirectory = "/home/meow";

    stateVersion = "23.11";
  };
}