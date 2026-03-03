# Library functions for Pegasus frontend configuration
{ lib }:
rec {
  # flatten nested attr sets with dot notation and convert to `key.key.key: value` strings
  mkConfigString =
    data:
    let
      flatten =
        prefix: attrs:
        lib.concatMap (
          k:
          let
            v = attrs.${k};
            fullKey = if prefix == "" then k else "${prefix}.${k}";
          in
          if lib.isAttrs v && !lib.isDerivation v then
            flatten fullKey v
          else
            [
              {
                name = fullKey;
                value = v;
              }
            ]
        ) (lib.attrNames attrs);

      # https://pegasus-frontend.org/docs/dev/meta-syntax/
      processFlowingText =
        text:
        let
          lines = lib.splitString "\n" text;
          # add tab indendation to lines
          processedLines = map (
            line:
            let
              trimmed = lib.strings.trim line;
            in
            # empty lines are replaced with a '.'
            if trimmed == "" then "\t." else "\t${trimmed}"
          ) lines;
        in
        lib.concatStringsSep "\n" processedLines;
    in
    lib.generators.toKeyValue {
      mkKeyValue =
        k: v:
        "${k}: ${if lib.isString v && lib.strings.hasInfix "\n" v then "\n${processFlowingText v}" else v}";
      listsAsDuplicateKeys = true;
    } (builtins.listToAttrs (flatten "" data));

  # generates a config file for a collection definition
  mkCollectionConfig =
    name: opts:
    mkConfigString (
      {
        collection = name;
      }
      // lib.optionalAttrs (opts.launch != null) {
        launch = opts.launch;
      }
      // lib.optionalAttrs (opts.workdir != null) {
        workdir = opts.workdir;
      }
      // lib.optionalAttrs (opts.extensions != null) {
        extensions = lib.concatStringsSep ", " opts.extensions;
      }
      // lib.optionalAttrs (opts.files != null) {
        files = opts.files;
      }
      // lib.optionalAttrs (opts.regex != null) {
        regex = opts.regex;
      }
      // lib.optionalAttrs (opts.directories != null) {
        directories = opts.directories;
      }
      // lib.optionalAttrs (opts.ignoreExtensions != null) {
        "ignore-extensions" = lib.concatStringsSep ", " opts.ignoreExtensions;
      }
      // lib.optionalAttrs (opts.ignoreFiles != null) {
        "ignore-files" = opts.ignoreFiles;
      }
      // lib.optionalAttrs (opts.ignoreRegex != null) {
        "ignore-regex" = opts.ignoreRegex;
      }
      // lib.optionalAttrs (opts.shortname != null) {
        shortname = opts.shortname;
      }
      // lib.optionalAttrs (opts.sortBy != null) {
        "sort-by" = opts.sortBy;
      }
      // lib.optionalAttrs (opts.summary != null) {
        summary = opts.summary;
      }
      // lib.optionalAttrs (opts.description != null) {
        description = opts.description;
      }
    );
}
