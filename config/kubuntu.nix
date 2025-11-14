{ pkgs, ... }:
let
  username = "meow";
in
{
  home = {
    packages = with pkgs; [
      nixfmt-rfc-style
      nixd

    ];

    inherit username;
    homeDirectory = "/home/${username}";
  };
}
