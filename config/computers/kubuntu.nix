{ pkgs, ... }:
let
  username = "meow";
in
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [

    ];
  };
}
