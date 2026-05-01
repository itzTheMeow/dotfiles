# inspired from: https://github.com/LukeCarrier/dotfiles/blob/e1170d516f703a331f539e9b3d9d810c0705a74b/lib/node.nix
final: pkgs:
let
  buildPnpmPackage =
    pkg:
    let
      chosenPNPM = pkg.pnpm or pkgs.pnpm_10;
    in
    pkgs.stdenv.mkDerivation (
      {
        inherit (pkg)
          pname
          version
          src
          ;

        nativeBuildInputs =
          (with pkgs; [
            nodejs
            npmHooks.npmInstallHook
            chosenPNPM
            pnpmConfigHook
            typescript
          ])
          ++ (pkg.nativeBuildInputs or [ ]);

        pnpmDeps = pkgs.fetchPnpmDeps {
          inherit (pkg) pname version src;
          pnpm = chosenPNPM;
          # https://nixos.org/manual/nixpkgs/stable/#javascript-pnpm-fetcherVersion
          fetcherVersion = pkg.pnpmDepsFetcherVersion or 3;
          hash = pkg.pnpmDepsHash;
        };

        dontNpmPrune = true;

        postBuild = ''
          pnpm run ${pkg.pnpmBuildScript or "build"}
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r . $out/
          runHook postInstall
        '';
      }
      // (pkg.extraAttrs or { })
    );
in
{
  inherit buildPnpmPackage;
}
