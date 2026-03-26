{
  _7zz,
  fetchurl,
  stdenv,
  wineWow64Packages,
  writeShellScriptBin,
  ...
}:
let
  gameSource = stdenv.mkDerivation {
    pname = "pvz-fusion-source";
    version = "3.4.2";
    src = fetchurl {
      url = "https://github.com/Teyliu/PVZF-Translation/releases/download/3.4.2_beta/PvZF.3.4.2.Multi-lang.Public.Beta.hotfix.3.By.Blooms.zip";
      sha256 = "sha256-mZgn1AIAR7zPVsdTKar4aftNp+PZHc6nMQMpX3+8fZU=";
    };
    nativeBuildInputs = [ _7zz ];
    dontUnpack = true;

    installPhase = ''
      7zz x $src -o$TMPDIR/game -y
      mv "$TMPDIR/game/Game Files" $out
    '';
  };
in
writeShellScriptBin "pvz-fusion" ''
  # needed for the game to launch
  export WINEDLLOVERRIDES="version=n,b"
  export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

  ${wineWow64Packages.staging}/bin/wine "${gameSource}/PlantsVsZombiesRH.exe" --melonloader.hideconsole
''
