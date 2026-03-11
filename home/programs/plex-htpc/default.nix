{ pkgs, xelib, ... }:
{
  home.packages = [
    ((xelib.injectCursorsFHS pkgs.plex-htpc).overrideAttrs (old: {
      # we have to remove the qt6 paths and switch to a more generic theme for it to run under bigscreen
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/plex-htpc \
          --unset QT_QUICK_CONTROLS_STYLE \
          --unset QT_PLUGIN_PATH \
          --unset QML2_IMPORT_PATH \
          --set QT_QPA_PLATFORMTHEME "fusion"
      '';
    }))
  ];
  xdg.dataFile."plex/inputmaps/keyboard.json".source = ./inputmap-keyboard.json;
}
