{
  fetchFromGitHub,
  fetchurl,
  stdenv,
  ...
}:
stdenv.mkDerivation {
  pname = "pegasus-theme-gameos-fire-skye";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "HomeStarRunnerTron";
    repo = "gameOS-fire-sKye";
    rev = "a892817e2291dbac9ab323e07694f530356315b4";
    sha256 = "sha256-puAfr1MN+bcHPvvislLz0p8JSaZJnmwYFEcrWbCzvSc=";
  };

  # replace the default logo with the pegasus one
  postPatch = ''
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/mmatyas/pegasus-frontend/7d08fdc5578c4cd499d696ea734809185c05a9c1/src/frontend/assets/logo.png";
        sha256 = "sha256-ydUUdyhJOm4jLUZS8hi/xHLQSLfO3J4c+60owQdJrtQ=";
      }
    } assets/images/gameOS-logo.png
  '';

  installPhase = ''
    mkdir -p $out
    cp -r . $out/
  '';
}
