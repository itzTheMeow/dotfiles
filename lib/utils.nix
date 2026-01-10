lib: rec {
  mkSecretFile = name: content: {
    "${name}" = {
      text = content;
      force = true;
      opinject = true;
    };
  };
  # optionally import a module if it exists
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];
  # convert string to title case
  toTitleCase =
    str:
    let
      firstChar = builtins.substring 0 1 str;
      rest = builtins.substring 1 (builtins.stringLength str) str;
    in
    (lib.strings.toUpper firstChar) + rest;

  # make a remoteview desktop file for dolphin
  mkRemoteView = name: address: {
    "${name}.desktop" = {
      text = ''
        [Desktop Entry]
        Charset=
        Icon=folder-remote
        Name=${name}
        Type=Link
        URL=${address}
      '';
    };
  };
}
