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
    rev = "18fda1d5b64acb53299d080b1cd0c38362ecaf18";
    hash = "sha256-C8Qw2ozizQCnfUR9MI3ZZlgKdwcJyJunZGWsASZ9zXY=";
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
