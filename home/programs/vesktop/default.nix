{ pkgs, pkgs-unstable, ... }:
let
  vesktop-custom = pkgs.symlinkJoin {
    name = "vesktop";
    paths = [ pkgs-unstable.vesktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/vesktop \
        --add-flags '--user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0"'
    '';
  };
in
{
  home.packages = [ vesktop-custom ];
  catppuccin.vesktop.enable = true;
}
