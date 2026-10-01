# TODO:26.11 drop when nixpkgs has libqalculate 5.11.0+
final: prev: {
  libqalculate = prev.libqalculate.overrideAttrs (old: {
    version = "5.12.0";
    src = final.fetchFromGitHub {
      owner = "qalculate";
      repo = "libqalculate";
      tag = "v5.12.0";
      hash = "sha256-f9FzFcu2LtBM6B6apYo7uobeR5uZVb02FxX7Kng/rRI=";
    };
  });
}
