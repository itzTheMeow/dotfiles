{
  fetchurl,
  p7zip,
  pkgs,
  wine,
  xelpkgs,
  ...
}:
# yeah yeah i know...
let
  winebin = "${wine}/bin/wine";

  gameISO = fetchurl {
    url = "https://archive.org/download/HellsKitchenPC/Hell%27s%20Kitchen.iso";
    name = "hells-kitchen.iso"; # needs an explicit name because of invalid characters
    sha256 = "sha256-inMLFySuSCT7OlHY7+8YPYP3V5gqxFbL7uKnd3n+irM=";
  };
  gameSource = pkgs.stdenv.mkDerivation {
    pname = "hells-kitchen-source";
    version = "1.1.5";
    nativeBuildInputs = [ p7zip ];
    dontUnpack = true;

    installPhase = ''
      # extract the exe and game source
      7z e ${gameISO} "Main/Files/Hell's Kitchen.exe" -o$out
      7z e ${gameISO} "Main/Files/HellsKitchen.zip" -o$out
    '';
  };

  setupScript = pkgs.writeShellScript "setup" ''
    # the game requires the installer to exist inside a cdrom to run
    mkdir -p $WINEPREFIX/dosdevices/d:/Main
    touch   "$WINEPREFIX/dosdevices/d:/Main/Hell's Kitchen-${gameSource.version}.exe"
    # set up the cdrom
    ${winebin} regedit ${pkgs.writeText "setup.reg" ''
      Windows Registry Editor Version 5.00

      ; type 4 is a cdrom, also set volume label to original disk name
      [HKEY_CURRENT_USER\Software\Wine\Drives]
      "d:"="Hell's Kitchen"
      "d:type"=dword:00000004
    ''}
    ${winebin}server -w
  '';
in
pkgs.writeShellScriptBin "hells-kitchen" ''
  # put the wine prefix in the data directory
  export WINEPREFIX="$HOME/.local/share/hells-kitchen"

  # initialize the wine prefix 
  ${xelpkgs.shared-wine-prefix}/bin/setup ${setupScript}

  # actually launch the game
  echo "Launching..."
  ${winebin} "${gameSource}/Hell's Kitchen.exe"
''
