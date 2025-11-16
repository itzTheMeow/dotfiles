{ pkgs, ... }:
let
  username = "root";
in
{
  imports = [
    ./common
  ];

  home = {
    inherit username;
    homeDirectory = "/root";

    packages = with pkgs; [

    ];
  };
}
