{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  installShellFiles,
}:
rustPlatform.buildRustPackage {
  pname = "rustic-unstable";
  version = "unstable-2025-02-12";

  src = fetchFromGitHub {
    owner = "rustic-rs";
    repo = "rustic";
    rev = "9820d6ad9fa524305c941736c21f37a043c7482a";
    hash = "sha256-2xSQ+nbP7/GsIWvj9sgG+jgIIIesfEW8T9z5Tijd90E=";
  };

  cargoHash = "sha256-4yiWIlibYldr3qny0KRRIHBqHCx6R9gDiiheGkJrwEY=";
  cargoBuildFlags = [ "--features=mount" ];

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    mv $out/bin/rustic $out/bin/rustic-unstable

    installShellCompletion --cmd rustic-unstable \
      --bash <($out/bin/rustic-unstable completions bash) \
      --fish <($out/bin/rustic-unstable completions fish) \
      --zsh <($out/bin/rustic-unstable completions zsh)
  '';

  meta = {
    homepage = "https://github.com/rustic-rs/rustic";
    description = "Fast, encrypted, deduplicated backups powered by pure Rust (unstable version)";
    mainProgram = "rustic-unstable";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    maintainers = [
      lib.maintainers.nobbz
      lib.maintainers.pmw
    ];
  };
}
