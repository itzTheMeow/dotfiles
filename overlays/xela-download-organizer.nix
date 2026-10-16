final: prev: {
  xela-download-organizer = final.callPackage (
    { buildGoModule }:
    buildGoModule {
      name = "download-organizer";
      src = ../go/download-organizer;
      vendorHash = null;
      meta.mainProgram = "download-organizer";
    }
  );
}
