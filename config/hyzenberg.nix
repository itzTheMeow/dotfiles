{ pkgs, ... }:
let
  username = "root";
in
{
  home = {
    inherit username;
    homeDirectory = "/root";

    packages = with pkgs; [

    ];
  };
}
