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
    rev = "7bc641a1496a314b9dec311bd0422851f7833d50";
    hash = "sha256-Kq3mERb7YyuY2hk+n59gQXWr6tFOdLz94P8a2wm/AbU=";
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
