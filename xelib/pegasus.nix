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

      flattened = builtins.listToAttrs (flatten "" data);
    in
    lib.generators.toKeyValue {
      mkKeyValue = lib.generators.mkKeyValueDefault { } ": ";
      listsAsDuplicateKeys = true;
    } flattened;
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
                Will not be linked if not provided, meaning you can change settings in the UI.
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
      }
      # link in theme/settings if provided
      // lib.optionalAttrs (theme != null) {
        "pegasus-frontend/themes/${theme.name}".source = theme.package;
      }
      // lib.optionalAttrs (theme != null && theme.settings != null) {
        "pegasus-frontend/theme_settings/${theme.name}.json".text = builtins.toJSON theme.settings;
      };
    };
}
