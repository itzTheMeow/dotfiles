{ pkgs }:
with pkgs;
kitty.overrideAttrs (old: {
  # we have to patch kitty to include mesa otherwise it won't run
  buildInputs = (old.buildInputs or [ ]) ++ [
    mesa
  ];
  postInstall = (old.postInstall or "") + ''
    wrapProgram $out/bin/kitty \
      --set LD_LIBRARY_PATH "${mesa}/lib"
  '';
})
