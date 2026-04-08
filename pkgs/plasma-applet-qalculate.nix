{
  cmake,
  fetchFromGitHub,
  gettext,
  kdePackages,
  lib,
  libqalculate,
  mpfr,
  pkg-config,
  readline,
  stdenv,
  ...
}:
stdenv.mkDerivation rec {
  pname = "plasma-applet-qalculate";
  version = "0.10.1";

  src = fetchFromGitHub {
    owner = "dschopf";
    repo = "plasma-applet-qalculate";
    rev = "v${version}";
    hash = "sha256-4NfgBP6PATOYHJo6Vtt/GdGDWLLvG3zmwaZfbMqhIZg=";
  };

  dontWrapQtApps = true;

  buildInputs = [
    kdePackages.kdeclarative
    kdePackages.ki18n
    kdePackages.libplasma
    libqalculate
    mpfr
    readline
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
