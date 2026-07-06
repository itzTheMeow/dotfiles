{
  fetchFromGitea,
  stdenv,
  ...
}:
stdenv.mkDerivation {
  name = "flixur-website";

  src = fetchFromGitea {
    domain = "forge.xela.codes";
    owner = "xela";
    repo = "flixur-website";
    rev = "511a38b45e98c406ee2f65971240caf1d9e801de";
    hash = "sha256-8CQwcgNvgeidHiCuN5BQg2bxH1xa5AVK1oxw5iN6FgQ=";
  };

  # installPhase = ''
  #   cp -r build $out
  # '';
}
