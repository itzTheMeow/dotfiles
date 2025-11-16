{ pkgs }:
with pkgs;
kitty.overrideAttrs (old: {
  buildInputs = (old.buildInputs or [ ]) ++ [
    mesa
  ];
  postInstall = (old.postInstall or "") + ''
    wrapProgram $out/bin/kitty \
      --set LD_LIBRARY_PATH "${mesa}/lib"
  '';
})
