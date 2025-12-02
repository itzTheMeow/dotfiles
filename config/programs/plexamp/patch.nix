{ pkgs, ... }:
let
  pname = "plexamp";
  version = "4.13.0";

  src = pkgs.fetchurl {
    url = "https://plexamp.plex.tv/plexamp.plex.tv/desktop/Plexamp-${version}.AppImage";
    name = "${pname}-${version}.AppImage";
    hash = "sha512-3Blgl3t21hH6lgDe5u3vy3I/3k9b4VM1CvoZg2oashkGXSDwV8q7MATN9YjsBgWysNXwdm7nQ/yrFQ7DiRfdYg==";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };
in
pkgs.stdenv.mkDerivation {
  inherit pname version;

  nativeBuildInputs = [ pkgs.copyDesktopItems ];

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "plexamp";
      exec = "plexamp";
      icon = "plexamp";
      desktopName = "Plexamp";
      comment = "A beautiful Plex music player";
      categories = [
        "Audio"
        "Music"
        "Player"
      ];
    })
  ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/lib/plexamp $out/share/icons/hicolor/scalable/apps

        # Copy the extracted AppImage contents
        cp -r ${appimageContents}/* $out/lib/plexamp/

        # Create wrapper script that runs the extracted binary with --no-sandbox
        cat > $out/bin/plexamp << EOF
    #!/usr/bin/env bash
    exec $out/lib/plexamp/plexamp --no-sandbox "\$@"
    EOF
        chmod +x $out/bin/plexamp

        # Install icon
        install -m 444 -D ${appimageContents}/plexamp.svg $out/share/icons/hicolor/scalable/apps/plexamp.svg

        runHook postInstall
  '';
}
