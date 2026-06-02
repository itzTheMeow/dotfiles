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
    rev = "00051ea19d9cd9b7f259cfbb57e4fefabf3fa85c";
    hash = "sha256-izsIwVfktQni73yokjOxSj31UeW/m01eyWL9C0G427o=";
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
