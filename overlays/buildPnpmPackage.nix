# inspired from: https://github.com/LukeCarrier/dotfiles/blob/e1170d516f703a331f539e9b3d9d810c0705a74b/lib/node.nix
final: prev: {
  buildPnpmPackage =
    pkg:
    let
      chosenPNPM = pkg.pnpm or final.pnpm_10;
    in
    final.stdenv.mkDerivation (
      {
        inherit (pkg)
          pname
          version
          src
          ;

        nativeBuildInputs =
          (with final; [
            nodejs
            npmHooks.npmInstallHook
            chosenPNPM
            pnpmConfigHook
            typescript
          ])
          ++ (pkg.nativeBuildInputs or [ ]);

        pnpmDeps = final.fetchPnpmDeps {
          inherit (pkg) pname version src;
          pnpm = chosenPNPM;
          # https://nixos.org/manual/nixpkgs/stable/#javascript-pnpm-fetcherVersion
          fetcherVersion = pkg.pnpmDepsFetcherVersion or 3;
          hash = pkg.pnpmDepsHash;
        };

        dontNpmPrune = true;

        postBuild =
          if pkg ? "pnpmBuildScript" then
            ''
              pnpm run ${pkg.pnpmBuildScript}
            ''
          else
            "";

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r . $out/
          runHook postInstall
        '';
      }
      // (pkg.extraAttrs or { })
    );
}
