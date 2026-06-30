{
  apt,
  bzip2,
  fetchFromGitea,
  fetchYarnDeps,
  gzip,
  nodejs,
  stdenv,
  xz,
  yarnConfigHook,
  zstd,
  ...
}:
stdenv.mkDerivation rec {
  name = "ios-apt";

  src = fetchFromGitea {
    domain = "forge.xela.codes";
    owner = "xela";
    repo = "ios-apt";
    rev = "30b35d1d28862dacca2217a2b2b2ee72fe62b5ef";
    hash = "sha256-8CQwcgNvgeiqHiCuN5BQg2bxH1xa5AVK1oxw5iN6FgQ=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-k8dauNO28MU13+s5Zc0WfOxxasZi5vhuoFz6k71GrxU=";
  };

  nativeBuildInputs = [
    yarnConfigHook
    nodejs
    # for the scripts
    apt
    bzip2
    gzip
    xz
    zstd
  ];

  buildPhase = ''
    # script has unsupported shebang in it
    patchShebangs scripts/

    # this builds the repo
    node .
  '';

  installPhase = ''
    cp -r build $out
  '';
}
