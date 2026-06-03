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
    rev = "aefe117e5634a4703283a4c48cc5487e65469e44";
    hash = "sha256-159PQh753p8+1+hXxx79o4QxXV5RT0vVtar4aWGTPBw=";
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
