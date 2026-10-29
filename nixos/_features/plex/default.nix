{
  pkgs,
  host,
  xelib,
  ...
}:
{
  environment.systemPackages = [
    pkgs.plexamp

    # plex, depending on the type of device
    (
      if (builtins.elem "console" host.type) then
        (pkgs.symlinkJoin {
          name = "plex-htpc-final";
          paths = [ (xelib.injectCursorsFHS pkgs.plex-htpc) ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
        })
      else
        (xelib.injectCursorsFHS pkgs.plex-desktop)
    )
  ];

  # configure input map for controller
  home-manager.importUser = [
    (hm: { xdg.dataFile."plex/inputmaps/keyboard.json".source = ./inputmap-keyboard.json; })
  ];

  persist.ed.home.userDirectories = [
    ".config/Plexamp"
  ];
}
