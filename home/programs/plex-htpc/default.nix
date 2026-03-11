{ pkgs, xelib, ... }:
{
  home.packages = [
    ((xelib.injectCursorsFHS pkgs.plex-htpc).overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        sed -i '2i export QT_QPA_PLATFORMTHEME=fusion' $out/bin/plex-htpc
        sed -i '3i unset QT_PLUGIN_PATH QML2_IMPORT_PATH QT_QUICK_CONTROLS_STYLE' $out/bin/plex-htpc
      '';
    }))
  ];
  xdg.dataFile."plex/inputmaps/keyboard.json".source = ./inputmap-keyboard.json;
}
