{
  fetchurl,
  p7zip,
  stdenv,
  symlinkJoin,
  wineWow64Packages,
  writeShellScriptBin,
  writeText,
  ...
}:
# yeah yeah i know...
let
  winebin = "${wineWow64Packages.staging}/bin/wine";

  gameISO = fetchurl {
    url = "https://archive.org/download/HellsKitchenPC/Hell%27s%20Kitchen.iso";
    name = "hells-kitchen.iso"; # needs an explicit name because of invalid characters
    sha256 = "sha256-inMLFySuSCT7OlHY7+8YPYP3V5gqxFbL7uKnd3n+irM=";
  };
  gameSource = stdenv.mkDerivation {
    pname = "hells-kitchen-source";
    version = "1.1.5";
    nativeBuildInputs = [ p7zip ];
    dontUnpack = true;

    installPhase = ''
      # extract the exe, game source, and images
      7z e ${gameISO} "Icon.ico" -o$out
      7z e ${gameISO} "Main/Files/Hell's Kitchen.exe" -o$out
      7z e ${gameISO} "Main/Files/HellsKitchen.zip" -o$out
      7z e ${gameISO} "Support/Manual/eng/Manual_files/frontpage.jpg" -o$out
      mv $out/frontpage.jpg $out/cover.jpg
    '';
  };

  launcher = writeShellScriptBin "hells-kitchen" ''
    # the game requires the installer to exist inside a cdrom to run
    ln -sfT ../drive_h "$WINEPREFIX/dosdevices/h:"
    mkdir -p $WINEPREFIX/drive_h/Main
    touch   "$WINEPREFIX/drive_h/Main/Hell's Kitchen-${gameSource.version}.exe"
    # set up the cdrom
    ${winebin} regedit ${writeText "setup.reg" ''
      Windows Registry Editor Version 5.00

      ; set H: as a cdrom
      [HKEY_LOCAL_MACHINE\Software\Wine\Drives]
      "h:"="cdrom"
      ; also disable the game's update checker
      [HKEY_LOCAL_MACHINE\Software\Wow6432Node\Hell's Kitchen]
      "CheckForUpdate"="Never"
    ''}
    ${winebin}server -w

    ${winebin} "${gameSource}/Hell's Kitchen.exe"
  '';
in
symlinkJoin {
  name = "game-hells-kitchen";
  paths = [
    gameSource
    launcher
  ];
}
