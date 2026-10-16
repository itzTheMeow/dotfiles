final: prev: {
  xela-download-organizer = final.callPackage (
    { buildGoModule }:
    buildGoModule {
      name = "download-organizer";
      src = ./.;
      vendorHash = null;
      meta.mainProgram = "download-organizer";
    }
  ) { };
}
