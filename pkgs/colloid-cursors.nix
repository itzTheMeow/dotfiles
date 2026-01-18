{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gitUpdater,
  variant ? "light", # light or dark
}:
let
  variantString = lib.optionalString (variant == "dark") "-dark";
in
assert lib.assertOneOf "variant" variant [
  "dark"
  "light"
];

stdenvNoCC.mkDerivation {
  pname = "colloid-cursors";
  version = "2025-07-19";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "Colloid-icon-theme";
    tag = "2025-07-19";
    hash = "sha256-x2SSaIkKm1415avO7R6TPkpghM30HmMdjMFUUyPWZsk=";
  };

  installPhase = ''
    runHook preInstall

    # Loosely based on the install script: https://github.com/vinceliuice/Colloid-icon-theme/blob/main/cursors/install.sh
    mkdir -p $out/share/icons
    cp -r cursors/dist${variantString} $out/share/icons/Colloid${variantString}-cursors

    runHook postInstall
  '';

  passthru.updateScript = gitUpdater { };

  meta = {
    description = "Colloid cursor theme";
    homepage = "https://github.com/vinceliuice/Colloid-icon-theme/tree/main/cursors#readme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
  };
}
