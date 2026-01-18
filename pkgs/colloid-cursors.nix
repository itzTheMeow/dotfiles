{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "colloid-cursors";
  version = "2025-02-09";

  src = pkgs.fetchFromGitHub {
    owner = "vinceliuice";
    repo = "Colloid-icon-theme";
    tag = "2025-02-09";
    hash = "sha256-x2SSaIkKm1415avO7R6TPkpghM30HmMdjMFUUyPWZsk=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons
    cp -r cursors/dist $out/share/icons/Colloid-cursors
    # We don't really need the "dark" cursors.
    # cp -r cursors/dist-dark $out/share/icons/Colloid-dark-cursors

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Colloid cursor theme";
    homepage = "https://github.com/vinceliuice/Colloid-icon-theme";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
  };
}
