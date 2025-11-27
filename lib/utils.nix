{
  # optionally import a module if it exists
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];
  # generates a secret placeholder for later replacement
  secretPlaceholder = name: "{{{-" + name + "-}}}";
}
