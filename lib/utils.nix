{
  mkSecretFile = name: content: {
    "${name}" = {
      text = content;
      force = true;
      opinject = true;
    };
  };
  # optionally import a module if it exists
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];
}
