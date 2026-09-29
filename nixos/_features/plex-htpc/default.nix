{
  pkgs,
  xelib,
  ...
}:
{
  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "plex-htpc-final";
      paths = [ (xelib.injectCursorsFHS pkgs.plex-htpc) ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
    })
  ];
  # configure input map for controller
  home-manager.importUser = [
    (hm: { xdg.dataFile."plex/inputmaps/keyboard.json".source = ./inputmap-keyboard.json; })
  ];
}
