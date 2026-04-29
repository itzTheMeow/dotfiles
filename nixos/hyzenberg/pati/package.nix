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
    rev = "cf0a11e52a5cb762dea2ea581210e0bfcf6d274d";
    hash = "sha256-uPxTCt3nys+umWFlrWnM8nPhO5MO59PTQeUKoHPJu4g=";
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
