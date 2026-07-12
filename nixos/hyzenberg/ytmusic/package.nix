{
  buildGoModule,
  buildPnpmPackage,
  fetchFromGitea,
}:
let
  src = fetchFromGitea {
    domain = "forge.xela.codes";
    owner = "xela-archive";
    repo = "YTMusic";
    rev = "db38f3be115d1d9d6cde79d150079fb78e1d6b60";
    hash = "sha256-sPx0dmVJcAvBtf2N6PU6rVJSEjQ+t5DVrGkDUtMfEb8=";
  };

  client = buildPnpmPackage {
    pname = "ytmusic";
    version = "0.0.0";
    inherit src;

    pnpmDepsHash = "sha256-CR2ccqqiQq7d++9yiZnv026nzaVV/RGxP+E5lEeaPtY=";
    pnpmBuildScript = "start";

    # we only want the dist folder
    extraAttrs.postInstall = ''
      find "$out" -mindepth 1 -maxdepth 1 ! -name dist -exec rm -rf {} +
      mv $out/dist/* $out/
      rmdir $out/dist
    '';
  };
in
buildGoModule {
  name = "ytmusic";
  version = "0.0.0";
  inherit src;
  vendorHash = "sha256-RCSmCLjvXv7Lgjo8FyaoqRj2QcxO71IEAb0zV9L2t9Q=";
  sourceRoot = "source/server";

  # force ts to disable workspaces
  GOWORK = "off";
  overrideModAttrs = (
    _: {
      GOWORK = "off";
    }
  );

  # we have to copy client dist to be embedded in the final binary
  preBuild = ''
    echo "Injecting frontend assets..."
    cp -r ${client} ./dist
  '';

  postInstall = ''
    mv $out/bin/YTMusic $out/bin/ytmusic
  '';
}
