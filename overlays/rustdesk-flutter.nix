# replace the tray icon with a less-obnoxious one (default has white bg)
final: prev: {
  #TODO:26.11 bump down
  rustdesk-flutter =
    (if (prev ? unstable) then prev.unstable else prev).rustdesk-flutter.overrideAttrs
      (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.librsvg ];
        postInstall = (old.postInstall or "") + ''
          mkdir -p $out/app/rustdesk/data/flutter_assets/assets
          rsvg-convert -w 128 -h 128 ${old.src}/flutter/assets/icon.svg \
            -o $out/app/rustdesk/data/flutter_assets/assets/icon.png
        '';
      });
}
