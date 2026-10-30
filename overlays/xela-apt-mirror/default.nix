# xela-apt-mirror: legacy-iOS apt repo mirroring service.
# External absolute-URL Filenames (jjolano-style GitHub-release debs) download
# directly and mirror into pool/external/<sha>.deb; mirrored index copies get
# their Filenames rewritten to those paths (unsigned repos only — indexes
# untouched by the rewrite are stored verbatim; when the rewrite must change
# an index's bytes and the Go stdlib cannot regenerate the variant (xz/zst/
# bz2/lzma), it is neither mirrored nor listed in the rewritten Release).
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
