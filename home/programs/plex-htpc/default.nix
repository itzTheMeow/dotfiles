{ pkgs, xelib, ... }:
{
  home.packages = [
    (pkgs.symlinkJoin {
      name = "plex-htpc-final";
      paths = [ (xelib.injectCursorsFHS pkgs.plex-htpc) ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
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
