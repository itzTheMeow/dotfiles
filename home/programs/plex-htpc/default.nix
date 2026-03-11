{ pkgs, xelib, ... }:
{
  home.packages = [
    (pkgs.symlinkJoin {
      name = "plex-htpc-final";
      paths = [ (xelib.injectCursorsFHS pkgs.plex-htpc) ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      # we have to unset the qt6 env and use a more generic theme for it to launch properly
      postBuild = ''
        wrapProgram $out/bin/plex-htpc \
          --unset QT_QUICK_CONTROLS_STYLE \
          --unset QT_PLUGIN_PATH \
          --unset QML2_IMPORT_PATH \
          --set QT_QPA_PLATFORMTHEME "fusion"
      '';
    })
  ];
  xdg.dataFile."plex/inputmaps/keyboard.json".source = ./inputmap-keyboard.json;
}
