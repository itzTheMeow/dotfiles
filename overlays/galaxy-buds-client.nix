#TODO:pr https://github.com/timschneeb/GalaxyBudsClient/pull/750
final: prev:
let
  base = prev.galaxy-buds-client;
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
