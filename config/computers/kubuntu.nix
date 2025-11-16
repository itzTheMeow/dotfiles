{ pkgs, ... }:
let
  username = "meow";
in
{
  imports = [
    ../programs/logisim
  ];

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
