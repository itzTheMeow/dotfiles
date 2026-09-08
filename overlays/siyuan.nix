# Based on nixpkgs PR #556604 ("siyuan: 3.7.3 -> 3.8.2"), bumped to 3.8.3
# locally: the fts5 + sqlcipher kernel tags with CGO, and the pandoc archives
# built from the Nix pandoc binary (pandoc-resources kept for the kernel).
# Requires the sqlcipher (CGO) kernel build for at-rest encryption of
# encrypted notebooks.
#
# Electron is taken from the (overlay-free) unstable import: siyuan 3.8.3
# declares electron 44.2.0, but neither nixos-26.05 nor nixos-unstable carry
# electron_44 yet, so we pin the newest packaged one (electron_43, 43.4.1).
# The kernel's go.mod requires go >= 1.26.5; stable only carries go 1.26.4, so
# go is also taken from the (overlay-free) unstable import.
#
# tesseract (eng only) is wrapped into the desktop app's PATH so the kernel's
# built-in OCR works: util/ocr.go probes `tesseract --version`/`--list-langs` at
# boot and auto-OCRs images in data/assets when the binary is reachable.
#
# siyuan-encrypted-notebook-ocr.patch adds OCR support for encrypted notebooks:
# each notebook's OCR text lives in a per-box encrypted sidecar
# (<box>/.siyuan/ocr-texts), keyed off the notebook DEK, and feeds the notebook's
# own full-text index. Prototype for an upstream PR; the upstream issue draft is
# patches/siyuan-encrypted-notebook-ocr.md (fill the TODO:pr URL below after
# filing the issue). Remove the patch once upstream ships the feature, otherwise
# it will conflict with the parent commit.
#TODO:pr https://github.com/NixOS/nixpkgs/pull/556604
final: prev:
let
  go = final.unstable.go_1_26;
  # buildGoModule is pre-bound to stable's go (1.26.4) in all-packages; rebuild
  # it bound to the newer go so the kernel's go.mod (go >= 1.26.5) is satisfied.
  buildGoModule = prev.callPackage "${prev.path}/pkgs/build-support/go/module.nix" {
    inherit go;
  };
  tesseract = prev.tesseract.override {
    enableLanguages = [ "eng" ];
  };
  siyuan =
    prev.callPackage
      (
        {
          lib,
          stdenv,
          fetchFromGitHub,
          replaceVars,
          pandoc,
          nodejs,
          pnpm_11,
          fetchPnpmDeps,
          pnpmConfigHook,
          pnpmBuildHook,
          electron,
          makeWrapper,
          makeDesktopItem,
          copyDesktopItems,
          nix-update-script,
          xdg-utils,
          tesseract,
          zip,
          darwin,
        }:
        let
          inherit (stdenv.hostPlatform) isLinux isDarwin system;

          pnpm = pnpm_11;

          platformIds = {
            "x86_64-linux" = "linux";
            "aarch64-linux" = "linux-arm64";
            "aarch64-darwin" = "darwin-arm64";
          };

          platformId = platformIds.${system} or (throw "Unsupported platform: ${system}");

          # The pandoc archive that electron-builder expects for each platform. We
          # build it from the Nix pandoc binary, so only the current platform's
          # archive is needed (the kernel uses Nix pandoc directly via the patch).
          pandocArchives = {
            "linux" = "pandoc-linux-amd64.zip";
            "linux-arm64" = "pandoc-linux-arm64.zip";
            "darwin-arm64" = "pandoc-darwin-arm64.zip";
          };

          pandocArchive = pandocArchives.${platformId};
        in
        stdenv.mkDerivation (finalAttrs: {
          pname = "siyuan";
          version = "3.8.3";

          src = fetchFromGitHub {
            owner = "siyuan-note";
            repo = "siyuan";
            tag = "v${finalAttrs.version}";
            hash = "sha256-+0CO1E0w4XCBRypjZftB0kRe01ebWI/piOySmDK5TL4=";
          };

          kernel = buildGoModule {
            name = "${finalAttrs.pname}-${finalAttrs.version}-kernel";
            inherit (finalAttrs) src;
            sourceRoot = "${finalAttrs.src.name}/kernel";
            vendorHash = "sha256-nlJD343y8j6WdFKDlMIMKGmyNap3eujWJOxXFji78e8=";

            patches = [
              (replaceVars ../patches/siyuan-set-pandoc-path.patch {
                pandoc_path = lib.getExe pandoc;
              })
              ../patches/siyuan-encrypted-notebook-ocr.patch
            ];

            # this patch makes it so that file permissions are not kept when copying files using the gulu package
            # this fixes a problem where it was copying files from the store and keeping their permissions
            # hopefully this doesn't break other functionality
            modPostBuild = ''
              chmod +w vendor/github.com/88250/gulu
              substituteInPlace vendor/github.com/88250/gulu/file.go \
                  --replace-fail "destMode := sourceinfo.Mode()" "destMode := os.FileMode(0644)"
            '';

            # Set flags and tags as per upstream's Dockerfile
            ldflags = [
              "-s"
              "-X 'github.com/siyuan-note/siyuan/kernel/util.Mode=prod'"
            ];
            tags = [
              "fts5"
              "sqlcipher"
            ];

            env.CGO_ENABLED = "1";

            # Tests are skipped here because many upstream tests make assumptions that
            # do not hold in the Nix sandbox (system MIME table, missing model.Conf
            # initialization, missing system fonts, our set-pandoc-path.patch, etc.).
            # They are run as a separate derivation via passthru.tests.kernel.
            doCheck = false;
          };

          nativeBuildInputs = [
            nodejs
            pnpmConfigHook
            pnpm
            zip
          ]
          ++ lib.optionals isLinux [
            pnpmBuildHook
            makeWrapper
            copyDesktopItems
          ]
          ++ lib.optionals isDarwin [
            darwin.autoSignDarwinBinariesHook
          ];

          pnpmDeps = fetchPnpmDeps {
            inherit (finalAttrs)
              pname
              version
              src
              sourceRoot
              ;
            inherit pnpm;
            fetcherVersion = 4;
            hash = "sha256-PItwjC+UnGbOu00AFKgyvWl67uxMVQv4C60v3CY6Nz0=";
          };

          sourceRoot = "${finalAttrs.src.name}/app";

          env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

          postConfigure = ''
            # Remove the prebuilt pandoc archives; we provide our own built from the
            # Nix pandoc binary below, and keep pandoc-resources for the kernel.
            rm -f pandoc/pandoc-*.zip

            # Build the current platform's pandoc archive from the Nix pandoc binary so
            # the electron-builder afterPack hook can extract it. The kernel itself uses
            # the Nix pandoc directly via set-pandoc-path.patch.
            (
              cd pandoc
              mkdir -p .tmp/bin
              cp ${lib.getExe pandoc} .tmp/bin/pandoc
              (
                cd .tmp
                zip -qr ../${pandocArchive} bin/pandoc
              )
              rm -rf .tmp
            )

            # link kernel into the correct starting place so that electron-builder can copy it to it's final location
            mkdir kernel-${platformId}
            ln -s ${finalAttrs.kernel}/bin/kernel kernel-${platformId}/SiYuan-Kernel

            cp -r ${electron.dist} electron-dist
            chmod -R u+w electron-dist
          '';

          postBuild = ''
            electronBuilderArgs=(
              --dir
              --config electron-builder-${platformId}.yml
              -c.electronDist=electron-dist
              -c.electronVersion=${electron.version}
              -c.mac.identity=null
            )

            npm exec electron-builder -- "''${electronBuilderArgs[@]}"
          '';

          installPhase = ''
            runHook preInstall
          ''
          + lib.optionalString isDarwin ''
            mkdir -p $out/Applications $out/bin

            cp -R build/mac*/*.app $out/Applications/SiYuan.app

            cat > $out/bin/siyuan << EOF
            #!${stdenv.shell}
            exec open -na "$out/Applications/SiYuan.app" --args "\$@"
            EOF
            chmod +x $out/bin/siyuan
          ''
          + lib.optionalString isLinux ''
            mkdir -p $out/share/siyuan

            cp -r build/*-unpacked/{locales,resources{,.pak}} $out/share/siyuan

            makeWrapper ${lib.getExe electron} $out/bin/siyuan \
                --chdir $out/share/siyuan/resources \
                --add-flags $out/share/siyuan/resources/app \
                --set ELECTRON_FORCE_IS_PACKAGED 1 \
                --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
                --suffix PATH : ${
                  lib.makeBinPath [
                    xdg-utils
                    tesseract
                  ]
                } \
                --inherit-argv0

            install -Dm644 src/assets/icon.svg $out/share/icons/hicolor/scalable/apps/siyuan.svg
          ''
          + ''
            runHook postInstall
          '';

          desktopItems = lib.optional isLinux (makeDesktopItem {
            name = "siyuan";
            desktopName = "SiYuan";
            comment = "Refactor your thinking";
            icon = "siyuan";
            exec = "siyuan %U";
            categories = [ "Utility" ];
          });

          passthru = {
            kernel = finalAttrs.kernel;

            updateScript = nix-update-script {
              extraArgs = [
                "--version-regex"
                "^v(\\d+\\.\\d+\\.\\d+)$"
                "--subpackage=kernel"
              ];
            };

            # Upstream kernel tests require model.Conf initialization, system fonts,
            # pandoc, and other assumptions that do not hold in the Nix sandbox during
            # the main build. Run them as a separate derivation so the package build
            # stays reliable while test results remain available via
            # nix-build -A siyuan.passthru.tests.kernel.
            tests.kernel = finalAttrs.kernel.overrideAttrs {
              pname = "${finalAttrs.pname}-kernel-test";
              doCheck = true;
              checkPhase = ''
                runHook preCheck
                go test -vet=off -tags=fts5,sqlcipher ./...
                runHook postCheck
              '';
              installPhase = "touch $out";
            };
          };

          meta = {
            description = "Privacy-first personal knowledge management system that supports complete offline usage, as well as end-to-end encrypted data sync";
            homepage = "https://b3log.org/siyuan/";
            license = lib.licenses.agpl3Plus;
            mainProgram = "siyuan";
            maintainers = with lib.maintainers; [
              tomasajt
              ltrump
              myul
            ];
            platforms = lib.attrNames platformIds;
          };
        })
      )
      {
        electron = final.unstable.electron_43;
        inherit tesseract;
      };
in
{
  inherit siyuan;
}
