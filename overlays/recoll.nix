# rcl7z.py (tar neighbor filter) still uses py7zr's pre-1.0 `readall()`,
# which py7zr >= 1.0 dropped (upstream memory-extract API is now
# extract(factory=...)). nixpkgs only ships py7zr 1.x, so 7z member
# indexing dies with "'SevenZipFile' object has no attribute 'readall'".
# Adapt the filter: materialize every member into ram via BytesIOFactory
# (capped per-member at recoll's own maxmembersize guard, like rclzip/rclrar
# do), then keep the filter's existing dict-based extraction as-is.
# recoll-nox inherits the patch (it overrides recoll).
final: prev: {
  recoll = prev.recoll.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      substituteInPlace $out/share/recoll/filters/rcl7z.py \
        --replace-fail "self.sevenzdic = self.sevenzip.readall()" \
        "                from py7zr.io import BytesIOFactory\n                _f7z = BytesIOFactory(self.em.maxmembersize)\n                self.sevenzip.extract(factory=_f7z)\n                self.sevenzdic = _f7z.products"
    '';
  });
}
