{
  fetchurl,
  stdenv,
  unzip,
  wineWow64Packages,
  writeShellScriptBin,
  writeText,
  ...
}:
let
  wine = wineWow64Packages.staging;
  winebin = "${wine}/bin/wine";

  dotnetVersion = "6.0.36";
  dotnetcore6 = fetchurl {
    url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/${dotnetVersion}/dotnet-runtime-${dotnetVersion}-win-x64.zip";
    sha256 = "sha256-wHfMw0LFVxzrejwG0d+8mbmJ7VpuDzoLC0UFMcEllhU=";
  };
  dotnetdesktop6 = fetchurl {
    url = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/${dotnetVersion}/windowsdesktop-runtime-${dotnetVersion}-win-x64.zip";
    sha256 = "sha256-AlhOMTaovTws1N5lTgxTmBtzln+pmO0zHV/o51uDXAk=";
  };

  shared-wine-prefix = stdenv.mkDerivation {
    name = "shared-wine-prefix";
    nativeBuildInputs = [
      wine
      unzip
    ];
    dontUnpack = true;

    installPhase = ''
      export HOME=$TMPDIR/wine-home
      export WINEPREFIX=$HOME
      export WINEDEBUG="-all" # disable debugging
      mkdir -p $WINEPREFIX

      # initialize wine
      echo "Initializing Wine..."
      wineboot --init
      wineserver -w

      # install dotnet for some games
      unzip ${dotnetcore6} -d "$WINEPREFIX/drive_c/Program Files/dotnet"
      unzip ${dotnetdesktop6} -d "$WINEPREFIX/drive_c/Program Files/dotnet"

      # move the initialized wine prefix to the store
      cp -r $WINEPREFIX $out

      # remove any hardware links and created user directory
      rm -rf $out/dosdevices $out/drive_c/users
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
      ${winebin}boot -u
      ${winebin}server -w

      # register DLLs that didnt get registered (on the 32 bit system)
      for dll in mmdevapi.dll wbemprox.dll; do
        ${winebin} 'C:\windows\syswow64\regsvr32.exe' /s $dll
      done

      # register the dotnet version
      ${winebin} regedit ${writeText "setup.reg" ''
        Windows Registry Editor Version 5.00

        [HKEY_LOCAL_MACHINE\Software\dotnet\Setup\InstalledVersions\x64\sharedhost]
        "Path"="C:\\Program Files\\dotnet\\"
        "Version"="${dotnetVersion}"
      ''}
      ${winebin}server -w

      # run exit script if provided
      if [ -f "$1" ]; then
        echo "Finishing..."
        $1
      fi
    fi
  '';

in
setupScript
