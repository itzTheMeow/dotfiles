{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  installShellFiles,
}:

rustPlatform.buildRustPackage rec {
  pname = "rustic-unstable";
  version = "unstable-2025-01-17";

  src = fetchFromGitHub {
    owner = "rustic-rs";
    repo = "rustic";
    rev = "1d75ad8e2f8bf7707b6a27436d1af1366d2968da";
    hash = "sha256-yzSFV4IDKXtVQbdwiRKuy07d0gunYmXmLkaIXDidm+s=";
  };

  cargoHash = "sha256-2Wt9kJ5TSl4On0ijp0Fu43uMRlkya6eAGjYPH6eKRQk=";
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
