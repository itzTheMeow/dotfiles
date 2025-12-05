{ pkgs, ... }:
let
  username = "meow";
in
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/meow";
  };
}
