#TODO:pr https://github.com/aristocratos/btop/pull/1905
final: prev: {
  btop = final.unstable.btop.overrideAttrs (old: {
    src = final.unstable.fetchFromGitHub {
      owner = "itzTheMeow";
      repo = "btop";
      rev = "2798cf48b85553986e39a1df9e4f496451f4c99a";
      hash = "sha256-gXhOrUQvEIKEQn1ClzA98Vx8pndWycvUQqJ1m0GJqLo=";
    };
  });
}
