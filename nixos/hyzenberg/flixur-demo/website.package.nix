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
    hash = "sha256-jEoL1TBlLJnIKQlQbelNZRZpJvSB3G55j0iBrDoV0Gs=";
  };

  # installPhase = ''
  #   cp -r build $out
  # '';
}
