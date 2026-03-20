{
  installShellFiles,
  just,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "nx";
  version = "1.0.0";
  dontUnpack = true;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall

    # actual nx binary
    install -Dm755 /dev/stdin "$out/bin/nx" <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail

    exec ${just}/bin/just \
      --justfile ${../scripts/nx.just} \
      --working-directory "$DOTFILES" \
      "$@"
    EOF

    # zsh completions
    installShellCompletion --cmd nx --zsh /dev/stdin <<'EOF'
    #compdef nx

    _nx() {
      local -a commands
      local raw_list

      while IFS=: read -r name desc; do
        [[ -n "$name" && -n "$desc" ]] && commands+=("$name:$desc")
      done < <(nx help | awk -F' # ' '/ # / {print $1 ":" $2}' | awk '{print $1 ":" substr($0, index($0, ":") + 1)}')

      _describe 'nx commands' commands
    }
    EOF

    runHook postInstall
  '';
}
