{ pkgs, xelib, ... }:
{
  home.packages = [ (xelib.injectCursorsFHS pkgs.plex-htpc) ];
  xdg.dataFile."plex/inputmaps/keyboard.json".source = ./inputmap-keyboard.json;
}
