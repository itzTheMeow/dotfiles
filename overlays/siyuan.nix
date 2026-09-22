# Thin overlay on nixpkgs-unstable's siyuan (3.8.2 => 3.8.4).
#
# Only changes vs the native package:
#   * version bump + src / pnpmDeps / kernel vendorHash regenerated for 3.8.4,
#   * kernel gains siyuan-encrypted-notebook-ocr.patch (per-box encrypted-at-rest
#     OCR sidecar; the only custom feature we keep — OP/master-password handling
#     moved to a plugin and dropped), plus a 3.8.4-compatible set-pandoc-path
#     patch (unstable's native one targets 3.8.2's initPandoc and no longer
#     applies),
#   * tesseract (eng) is wrapped into the desktop app PATH so the kernel's
#     built-in OCR can find it (native PATH only has xdg-utils).
#
# The two re-declared build phases exist because `postConfigure` embeds the
# kernel derivation path at eval time (must relink the patched kernel) and
# `installPhase` must extend PATH with tesseract.
final: prev:
let
  inherit (final) lib;
  unstable = final.unstable;

  version = "3.8.4";

  src = unstable.fetchFromGitHub {
    owner = "siyuan-note";
    repo = "siyuan";
    tag = "v${version}";
    hash = "sha256-6UwmOxGyK4JC52TP88sE2JcYX8lOHdqtJmzWFdj350M=";
  };

  tesseract = unstable.tesseract.override {
    enableLanguages = [ "eng" ];
  };

  # unstable's native siyuan derivation; keep all its args/patches, just point
  # kernel at the 3.8.4 src + our OCR sidecar patch.
  base = unstable.siyuan;

  kernel = base.kernel.overrideAttrs (old: {
    name = "siyuan-${version}-kernel";
    inherit src;
    sourceRoot = "${src.name}/kernel";
    # Replace unstable's native 3.8.2-era set-pandoc-path patch (fails on 3.8.4's
    # refactored initPandoc) with a 3.8.4-compatible one; keep the OCR sidecar as
    # the only custom feature.
    patches = [
      (unstable.replaceVars ../patches/siyuan-set-pandoc-path.patch {
        pandoc_path = lib.getExe unstable.pandoc;
      })
      ../patches/siyuan-encrypted-notebook-ocr.patch
    ];
    # 3.8.4's gulu copyFileWithOptions sets destMode from sourceinfo.Mode();
    # normalize it so files copied out of the store don't keep read-only perms.
    modPostBuild = ''
      chmod +w vendor/github.com/88250/gulu
      substituteInPlace vendor/github.com/88250/gulu/file.go \
          --replace-fail "destMode := sourceinfo.Mode()" "destMode := os.FileMode(0644)"
    '';

    vendorHash = "sha256-atcvKc9q4Spuo20Ik8aFENgFf4zGBy8RiPhJsWUHr6w=";
  });

  platformIds = {
    "x86_64-linux" = "linux";
    "aarch64-linux" = "linux-arm64";
    "aarch64-darwin" = "darwin-arm64";
  };
  platformId =
    platformIds.${unstable.stdenv.hostPlatform.system}
      or (throw "Unsupported platform: ${unstable.stdenv.hostPlatform.system}");
  pandocArchives = {
    "linux" = "pandoc-linux-amd64.zip";
    "linux-arm64" = "pandoc-linux-arm64.zip";
    "darwin-arm64" = "pandoc-darwin-arm64.zip";
  };
  pandocArchive = pandocArchives.${platformId};
in
{
  siyuan = base.overrideAttrs (old: {
    inherit version src;

    kernel = kernel;

    pnpmDeps = unstable.fetchPnpmDeps {
      inherit (old) pname;
      pnpm = unstable.pnpm_11;
      version = version;
      src = src;
      sourceRoot = "${src.name}/app";
      fetcherVersion = 4;
      hash = "sha256-oj86MLPIAIABmd6K4au0XQTSNGuSjjoRmPj8SKcJ838=";
    };

    postConfigure = ''
      # Remove the prebuilt pandoc archives; we provide our own built from the
      # Nix pandoc binary below, and keep pandoc-resources for the kernel.
      rm -f pandoc/pandoc-*.zip

      (
        cd pandoc
        mkdir -p .tmp/bin
        cp ${lib.getExe unstable.pandoc} .tmp/bin/pandoc
        (
          cd .tmp
          zip -qr ../${pandocArchive} bin/pandoc
        )
        rm -rf .tmp
      )

      # link kernel into the correct starting place so that electron-builder can copy it to it's final location
      mkdir kernel-${platformId}
      ln -s ${kernel}/bin/kernel kernel-${platformId}/SiYuan-Kernel

      cp -r ${unstable.electron.dist} electron-dist
      chmod -R u+w electron-dist
    '';

    installPhase =
      old.installPhase
      + lib.optionalString unstable.stdenv.hostPlatform.isLinux ''
        # tesseract is required by the kernel's built-in OCR (util/ocr.go probes
        # `tesseract --version`/`--list-langs` at boot); extend PATH after the
        # native wrapper is created.
        wrapProgram $out/bin/siyuan \
          --suffix PATH : ${lib.makeBinPath [ tesseract ]}
      '';
  });
}
