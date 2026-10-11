#TODO:pr https://github.com/timschneeb/GalaxyBudsClient/pull/750
final: prev:
let
  base = prev.galaxy-buds-client.override {
    # the PR is based on master, whose global.json pins SDK 10.0.300
    # (rollForward=latestPatch won't accept sdk_10_0_1xx / 10.0.111)
    dotnetCorePackages = prev.dotnetCorePackages // {
      sdk_10_0_1xx = prev.dotnetCorePackages.sdk_10_0_3xx;
    };
    # nugetDeps isn't a drv attr, so swap it through the buildDotnetModule
    # call itself; deps were regenerated for the PR source via passthru.fetch-deps
    buildDotnetModule =
      attrs:
      prev.buildDotnetModule (
        attrs
        // {
          nugetDeps = ../patches/galaxy-buds-client-deps.json;
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
  });
}
