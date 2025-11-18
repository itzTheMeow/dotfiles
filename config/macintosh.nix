{ pkgs, ... }:
let
  username = "meow";
in
{
  imports = [
    ./common
    ./common/darwin.nix
    ./common/desktop.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/Users/meow";
  };
}
