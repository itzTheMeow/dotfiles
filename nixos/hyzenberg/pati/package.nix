{
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
}:
buildNpmPackage {
  pname = "pati";
  version = "0.0.0";

  src = fetchFromGitHub {
    owner = "brayden-indigo";
    repo = "Pati";
    rev = "00b7b10dc634a8c5f760ae2668146b18c211118e";
    hash = "sha256-wN28LFc8Ox9+6vveuc07mu3lX+JDmXDFoI/GYeN6ZNI=";
  };
  npmDepsHash = "sha256-p14wlfLRh65ASGfY/COtwGoh7zjxNSgtn8XI1wKD2aQ=";

  # skip build script
  dontNpmBuild = true;

  # output a binary to the code
  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    makeWrapper ${nodejs}/bin/node $out/bin/pati \
      --add-flags "$out/lib/node_modules/workspace/pati.js"
  '';
}
