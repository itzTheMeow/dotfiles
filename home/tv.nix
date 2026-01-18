{ pkgs, ... }:
let
  username = "tv";
in
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/tv";
  };
}
