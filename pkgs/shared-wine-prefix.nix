{
  stdenv,
  wine,
  writeShellScriptBin,
  ...
}:
let
  shared-wine-prefix = stdenv.mkDerivation {
    name = "shared-wine-prefix";
    nativeBuildInputs = [ wine ];
    dontUnpack = true;

    installPhase = ''
      export HOME=$TMPDIR/wine-home
      export WINEPREFIX=$HOME
      export WINEDEBUG="-all" # disable debugging
      mkdir -p $WINEPREFIX

      echo "Initializing Wine..."
      wineboot --init
      wineserver -w

      # move the initialized wine prefix to the store
      cp -r $WINEPREFIX $out

      # remove any hardware links and created user directory
      rm -rf $out/dosdevices $out/users/$USER
    '';
  };

  setupScript = writeShellScriptBin "setup" ''
    export WINEDEBUG="-all" # disable debugging
    export WINEDLLOVERRIDES="mscoree=n" # disable mono popup

    if [ ! -d "$WINEPREFIX" ]; then
      echo "Copying..."

      # link the shared wine prefix to the local one individually (keeps directory permissions)
      cd "${shared-wine-prefix}/drive_c"
      find . -type d -exec mkdir -p "$WINEPREFIX/drive_c/{}" \;
      find . -type f -exec ln -s "${shared-wine-prefix}/drive_c/{}" "$WINEPREFIX/drive_c/{}" \;
      cd -

      # set up link to c drive and system root
      mkdir -p "$WINEPREFIX/dosdevices"
      ln -sfT ../drive_c "$WINEPREFIX/dosdevices/c:"
      ln -sfT / "$WINEPREFIX/dosdevices/z:"

      # initialize wine registry/home
      echo "Initializing..."
      ${wine}/bin/wineboot -u
      ${wine}/bin/wineserver -w

      # register DLLs that didnt get registered
      ${wine}/bin/wine regsvr32 /s mmdevapi.dll

      # run exit script if provided
      if [ -f "$1" ]; then
        echo "Finishing..."
        $1
      fi
    fi
  '';

in
setupScript
