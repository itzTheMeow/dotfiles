#TODO:pr https://github.com/aristocratos/btop/pull/1905
final: prev: {
  btop = final.unstable.btop.overrideAttrs (old: {
    src = final.unstable.fetchFromGitHub {
      owner = "itzTheMeow";
      repo = "btop";
      rev = "2b939904cde0cd88943c4cfc158b0d00ed68aae3";
      hash = "sha256-ElD/dghJZuMEjR6sctD/03LYFVttUZ4qNNqZ1jMgdc0=";
    };
  });
}
