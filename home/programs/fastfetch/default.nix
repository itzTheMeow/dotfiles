{ ... }:
{
  programs.fastfetch = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ./config.json);
  };
  home.file.".config/fastfetch/logo.txt".source = ./logo.txt;
}
