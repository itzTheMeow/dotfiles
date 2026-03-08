{
  fetchurl,
  stdenv,
  unzip,
  wineWow64Packages,
  ...
}:
let
  wine = wineWow64Packages.staging;

  dotnetVersion = "6.0.36";
  dotnetcore6 = fetchurl {
    url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/${dotnetVersion}/dotnet-runtime-${dotnetVersion}-win-x64.zip";
    sha256 = "sha256-wHfMw0LFVxzrejwG0d+8mbmJ7VpuDzoLC0UFMcEllhU=";
  };
  dotnetdesktop6 = fetchurl {
    url = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/${dotnetVersion}/windowsdesktop-runtime-${dotnetVersion}-win-x64.zip";
    sha256 = "sha256-AlhOMTaovTws1N5lTgxTmBtzln+pmO0zHV/o51uDXAk=";
  };
in
stdenv.mkDerivation {
  name = "wine-prefix";
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
}
