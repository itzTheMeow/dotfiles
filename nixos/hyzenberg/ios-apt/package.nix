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
    rev = "478f1ddf81a28f309d1c38910aef00863cdf5b25";
    hash = "sha256-wg12xSEpWaq9wPSYZlTrao86Sq4wbSi6tNjMMB9F5Ko=";
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
