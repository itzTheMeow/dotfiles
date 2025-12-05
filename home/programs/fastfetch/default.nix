{ ... }:
{
  programs.fastfetch = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ./config.json);
  };
  home.file.".config/fastfetch/logo.txt".source = ./logo.txt;
  home.file.".config/fastfetch/config-title.json".source = ./config-title.json;
  home.file.".config/fastfetch/config-os.json".source = ./config-os.json;
}
