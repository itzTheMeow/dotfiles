{
  # optionally import a module if it exists
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];
  # write a secret file using bash in an activation script
  writeSecretFile = path: content: ''
    mkdir -p "$(dirname "$HOME/${path}")"
    rm -f "$HOME/${path}"
    cat > "$HOME/${path}" <<EOF
    ${content}
    EOF
    chmod 600 "$HOME/${path}"
  '';
}
