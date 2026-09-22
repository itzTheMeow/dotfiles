{ stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "siyuan-op-unlock";
  version = "0.1.0";

  src = ./src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -rT "$src" "$out"
    runHook postInstall
  '';
}
