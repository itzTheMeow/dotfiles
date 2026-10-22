final: prev: {
  xela-apt-mirror = final.callPackage (
    { buildGoModule }:
    buildGoModule {
      name = "xela-apt-mirror";
      src = ./.;
      vendorHash = null;
      meta.mainProgram = "xela-apt-mirror";
    }
  ) { };
}
