# Library functions for Pegasus frontend configuration
{ lib }:
rec {
  # flatten nested attr sets with dot notation and convert to `key.key.key: value` strings
  mkConfigString =
    data:
    let
      # flatten the attr set itself
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

      # properly formats a multiline string
      # https://pegasus-frontend.org/docs/dev/meta-syntax/
      processFlowingText =
        text:
        let
          lines = lib.splitString "\n" (lib.strings.trim text);
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
      listsAsDuplicateKeys = true; # arrays will be converted to duplicate keys, which the format supports
    } (builtins.listToAttrs (flatten "" data));

  # generates a single metadata file containing all games
  mkGamesConfig =
    games:
    lib.concatMapStringsSep "\n" (
      game:
      let
        gameAttrs =
          { }
          // lib.optionalAttrs (game.sortBy != null) {
            "sort-by" = game.sortBy;
          }
          // lib.optionalAttrs (game.files != null && game.files != [ ]) {
            file = game.files;
          }
          // lib.optionalAttrs (game.developers != null && game.developers != [ ]) {
            developer = game.developers;
          }
          // lib.optionalAttrs (game.publishers != null && game.publishers != [ ]) {
            publisher = game.publishers;
          }
          // lib.optionalAttrs (game.genres != null && game.genres != [ ]) {
            genre = game.genres;
          }
          // lib.optionalAttrs (game.tags != null && game.tags != [ ]) {
            tag = game.tags;
          }
          // lib.optionalAttrs (game.summary != null) {
            summary = game.summary;
          }
          // lib.optionalAttrs (game.description != null) {
            description = game.description;
          }
          // lib.optionalAttrs (game.players != null) {
            players = game.players;
          }
          // lib.optionalAttrs (game.release != null) {
            release = game.release;
          }
          // lib.optionalAttrs (game.rating != null) {
            rating = game.rating;
          }
          // lib.optionalAttrs (game.launch != null) {
            launch = game.launch;
          }
          // lib.optionalAttrs (game.workdir != null) {
            workdir = game.workdir;
          };
      in
      ''
        game: ${game.title}
        ${mkConfigString gameAttrs}
      ''
    ) games;

  # generates a config file for a collection definition
  mkCollectionConfig =
    name: opts:
    let
      configAttrs =
        { }
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
        };
    in
    ''
      collection: ${name}
      ${mkConfigString configAttrs}
    '';
}
