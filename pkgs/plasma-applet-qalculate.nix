{
  cmake,
  fetchFromGitHub,
  gettext,
  kdePackages,
  lib,
  libqalculate,
  mpfr,
  pkg-config,
  stdenv,
  ...
}:
stdenv.mkDerivation rec {
  pname = "plasma-applet-qalculate";
  version = "0.11.3";

  src = fetchFromGitHub {
    owner = "dschopf";
    repo = "plasma-applet-qalculate";
    rev = "v${version}";
    hash = "sha256-KWdb/TDUuYONU3fbGF5qs9zOzjpz+siDqCMVJlN6NNQ=";
  };

  dontWrapQtApps = true;

  buildInputs = [
    kdePackages.ki18n
    kdePackages.libplasma
    libqalculate
    mpfr
  ];

  nativeBuildInputs = [
    cmake
    gettext
    kdePackages.extra-cmake-modules
    pkg-config
  ];

  meta = with lib; {
    description = "Qalculate applet for plasma desktop";
    homepage = "https://github.com/dschopf/plasma-applet-qalculate";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
