{
  buildPnpmPackage,
  fetchFromGitea,
  makeWrapper,
  pkgs,
}:
buildPnpmPackage {
  pname = "xela-website";
  version = "0.0.0";

  src = fetchFromGitea {
    domain = "forge.xela.codes";
    owner = "xela";
    repo = "website";
    rev = "aa87f569d555a483a5a167eb42e0a8837c2881ca";
    hash = "sha256-9KXxQxURTKk2a42ndcXP1+ifIiUEiN+erhg//fpbLmA=";
  };

  pnpmDepsHash = "sha256-NycW2NS5MJ8geLUUHaKwlXM/WEjwRxOPRsCVF7+vJ7o=";
  pnpmBuildScript = "build";

  nativeBuildInputs = [ makeWrapper ];

  extraAttrs = {
    postInstall = ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/xela-website \
        --chdir "$out" \
        --add-flags "."
    '';
  };
}
