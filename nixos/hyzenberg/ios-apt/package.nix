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
    rev = "d61e74a13adc23814256c1b8d3633dc09e30fe89";
    hash = "sha256-Q7SiLJBdqwY5ke3RPdXpctvCYf3hsekHnbwaFEqzEq4=";
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
