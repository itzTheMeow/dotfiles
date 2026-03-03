{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    boolToString
    mkIf
    mkOption
    types
    ;
  cfg = config.programs.pegasus-frontend;

  validProviders = [
    "pegasus_media"
    "steam"
    "gog"
    "es2"
    "logiqx"
    "lutris"
    "skraper"
  ];

  inherit (import ./pegasus-lib.nix { inherit lib; })
    mkConfigString
    mkCollectionConfig
    ;
in
{
  options.programs.pegasus-frontend = {
    enable = lib.mkEnableOption "pegasus-frontend";
    package = lib.mkPackageOption pkgs "pegasus-frontend" { };

    settings = mkOption {
      type = types.submodule {
        options = {
          verify-files = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to verify game files on startup";
          };
          input-mouse-support = mkOption {
            type = types.bool;
            default = true;
            description = "Enable mouse input support";
          };
          fullscreen = mkOption {
            type = types.bool;
            default = true;
            description = "Start in fullscreen mode";
          };
        };
      };
      default = { };
      description = "General Pegasus settings";
    };

    theme = mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            package = mkOption {
              type = types.package;
              description = "The theme package to use";
            };
            name = mkOption {
              type = types.str;
              default = "theme";
              description = "The theme directory name";
            };
            settings = mkOption {
              type = types.nullOr types.attrs;
              default = null;
              description = ''
                Theme-specific settings as JSON.
                Will not be managed if not provided, meaning you can change theme settings in the UI.
              '';
            };
          };
        }
      );
      default = null;
      description = "Pegasus theme configuration";
    };

    enableProviders = mkOption {
      type = types.listOf (types.enum validProviders);
      default = validProviders;
      description = "List of enabled game providers";
    };

    keybinds = mkOption {
      type = types.submodule {
        options =
          lib.mapAttrs
            (
              name: default:
              mkOption {
                type = types.str;
                inherit default;
                description = "Key binding for ${name}";
              }
            )
            {
              "page-up" = "PgUp,GamepadL2";
              "page-down" = "PgDown,GamepadR2";
              "prev-page" = "Q,A,GamepadL1";
              "next-page" = "E,D,GamepadR1";
              "menu" = "F1,GamepadStart";
              "filters" = "F,GamepadY";
              "details" = "I,GamepadX";
              "cancel" = "Esc,Backspace,GamepadB";
              "accept" = "Return,Enter,GamepadA";
            };
      };
      default = { };
      description = "Key bindings for Pegasus controls";
    };

    gameDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of absolute paths to game directories";
    };

    favorites = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      description = ''
        List of favorite game identifiers.
        Format: `collection:id`
        YOU WILL NOT BE ABLE TO MANAGE FAVORITES IN THE UI IF THIS IS SET
      '';
    };

    # https://pegasus-frontend.org/docs/user-guide/meta-files/
    collections = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            # Basics
            launch = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "A common launch command for the games in this collection. If a game has its own custom launch command, that will override this field.";
            };
            workdir = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "The default working directory used when launching a game. Defaults to the directory of the launched program.";
            };
            # Include Files
            extensions = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "A list of file extensions (without the . dot). All files with these extensions (including those in subdirectories) will be included.";
            };
            files = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "A single file or a list of files to add to the collection. You can use either absolute paths or paths relative to the metadata file.";
            };
            regex = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "A Perl-compatible regular expression string, without leading or trailing slashes. Relative file paths matching the regex will be included.";
            };
            directories = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "A list of directories to search for matching games.";
            };
            # Exclude Files
            ignoreExtensions = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Similarly to `extensions`.";
            };
            ignoreFiles = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Similarly to `files`.";
            };
            ignoreRegex = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Similarly to `regex`.";
            };
            # Metadata
            shortname = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "An optional short name for the collection, in lowercase. Often an abbreviation, like MAME, NES, etc.";
            };
            sortBy = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "An alternate name that should be used for sorting.";
            };
            summary = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "A short description of the collection in one paragraph.";
            };
            description = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "A possibly longer description of the collection.";
            };
          };
        }
      );
      default = { };
      description = "Collections define which files in the directory should be treated as games.";
    };
  };

  config =
    let
      settings = cfg.settings;
      theme = cfg.theme;
    in
    mkIf cfg.enable {
      home.packages = [ cfg.package ];
      xdg.configFile = {
        "pegasus-frontend/settings.txt".text = mkConfigString {
          general = {
            theme = if theme == null then ":/themes/pegasus-theme-grid/" else "themes/${theme.name}/";
            verify-files = boolToString settings.verify-files;
            input-mouse-support = boolToString settings.input-mouse-support;
            fullscreen = boolToString settings.fullscreen;
          };
          providers = lib.listToAttrs (
            map (provider: {
              name = "${provider}.enabled";
              value = boolToString (lib.elem provider cfg.enableProviders);
            }) validProviders
          );
          keys = cfg.keybinds;
        };
        "pegasus-frontend/game_dirs.txt".text = lib.concatStringsSep "\n" (
          cfg.gameDirs
          # add the collections metadata if set
          ++ lib.optionals (cfg.collections != { }) [
            (pkgs.runCommand "pegasus-metadata" { } (
              lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  name: opts:
                  let # hash the name just in case
                    filename = "${lib.substring 0 32 (builtins.hashString "sha256" name)}.metadata.pegasus.txt";
                  in
                  "cp ${pkgs.writeText filename (mkCollectionConfig name opts)} $out/${filename}"
                ) cfg.collections
              )
            ))
          ]
        );
      }
      # link in theme/settings if provided
      // lib.optionalAttrs (theme != null) {
        "pegasus-frontend/themes/${theme.name}".source = theme.package;
      }
      // lib.optionalAttrs (theme != null && theme.settings != null) {
        "pegasus-frontend/theme_settings/${theme.name}.json".text = builtins.toJSON theme.settings;
      }
      # only manage favorites if its set
      // lib.optionalAttrs (cfg.favorites != null) {
        "pegasus-frontend/favorites.txt".text = lib.concatStringsSep "\n" cfg.favorites;
      };
    };
}
