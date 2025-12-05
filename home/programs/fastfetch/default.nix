{ hostname, ... }:
let
  accent =
    if hostname == "kubuntu" then
      "#cba6f7"
    else if hostname == "hyzenberg" then
      "#f38ba8"
    else if hostname == "macintosh" then
      "#b4befe"
    else
      "blue";
in
{
  programs.fastfetch = {
    enable = true;
    settings = builtins.fromJSON (
      builtins.replaceStrings [ "__ACCENT__" ] [ accent ] (builtins.readFile ./config.json)
    );
  };
  home.file.".config/fastfetch/logo.txt".source = ./logo.txt;
  home.file.".config/fastfetch/config-title.json".source = ./config-title.json;
  home.file.".config/fastfetch/config-os.json".source = ./config-os.json;
}
