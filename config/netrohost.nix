{ pkgs, ... }:
let
  username = "meow";
in
{
  imports = [
    ./common
  ];

  home = {
    inherit username;
    homeDirectory = "/home/meow";
  };
}
