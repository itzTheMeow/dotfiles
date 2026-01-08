{ pkgs, ... }:
let
  inherit (pkgs.plexamp) pname version src;
  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
in
# plexamp wont work on non-nixos systems, so extract and run the binary directly instead
pkgs.stdenv.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/lib/plexamp $out/share/applications $out/share/icons/hicolor/scalable/apps

        # Copy extracted AppImage contents
        cp -r ${appimageContents}/* $out/lib/plexamp/

        # Create wrapper that runs with --no-sandbox (required on non-NixOS)
        cat > $out/bin/plexamp << EOF
    #!/usr/bin/env bash
    exec $out/lib/plexamp/plexamp --no-sandbox "\$@"
    EOF
        chmod +x $out/bin/plexamp

        # Install desktop file and icon from extracted contents
        install -m 444 -D ${appimageContents}/plexamp.desktop $out/share/applications/plexamp.desktop
        install -m 444 -D ${appimageContents}/plexamp.svg $out/share/icons/hicolor/scalable/apps/plexamp.svg
        substituteInPlace $out/share/applications/plexamp.desktop \
          --replace 'Exec=AppRun' 'Exec=plexamp'

        runHook postInstall
  '';
}
