#TODO:pr https://github.com/timschneeb/GalaxyBudsClient/pull/750
final: prev:
let
  base = prev.galaxy-buds-client.override {
    # the PR is based on master, whose global.json pins SDK 10.0.300, but
    # nixpkgs ships 10.0.1xx. Use sdk_10_0_4xx (present in both nixos-26.05
    # and nixos-unstable) and relax global.json's rollForward to latestFeature
    # so the 4xx band satisfies the 10.0.300 requirement.
    dotnetCorePackages = prev.dotnetCorePackages // {
      sdk_10_0_1xx = prev.dotnetCorePackages.sdk_10_0_4xx;
    };
    # nugetDeps isn't a drv attr, so swap it through the buildDotnetModule
    # call itself; deps were regenerated for the PR source via passthru.fetch-deps
    buildDotnetModule =
      attrs:
      prev.buildDotnetModule (
        attrs
        // {
          nugetDeps = ./deps.json;
        }
      );
  };
in
{
  galaxy-buds-client = base.overrideAttrs (old: {
    src = final.fetchFromGitHub {
      owner = "itzTheMeow";
      repo = "GalaxyBudsClient";
      rev = "5f9d8a647e30fef1e5a2fb372ab14d9fbe02ff52";
      hash = "sha256-BlX7ixGoUj/WG4AsFOHuCv9XDFMrckjoRbsTFoomuTw=";
    };
    postPatch = (old.postPatch or "") + ''
      substituteInPlace global.json \
        --replace-fail '"rollForward": "latestPatch"' '"rollForward": "latestFeature"'
    '';
  });
}
