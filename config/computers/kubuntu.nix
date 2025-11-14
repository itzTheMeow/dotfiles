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
  programs.bash.shellAliases = {
    nixup_currentflake = "echo -n kubuntu";
  };
}
