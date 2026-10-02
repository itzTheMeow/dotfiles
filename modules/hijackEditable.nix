{
  home-manager.sharedModules = [
    (
      { config, lib, ... }:
      let
        cfg = config.home.hijackEditable;

        # the home.file key has to be exactly what the declaring module used
        toPath = path: if lib.hasPrefix "/" path then path else "\${HOME}/${path}";

        entryName =
          path:
          "hijackEditable-"
          + lib.strings.sanitizeDerivationName (
            lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" path)
          );
      in
      {
        options.home.hijackEditable = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.mode = lib.mkOption {
                type = lib.types.str;
                default = "644";
                description = "Permission bits of the runtime-owned copy.";
              };
            }
          );
          default = { };
          description = ''
            home-manager files to keep user-owned and editable at runtime. The
            managed file is linked as `<path>.hm` and copied over the real path
            on every activation, so live edits survive until the next activation.
          '';
        };

        config = lib.mkIf (cfg != { }) {
          # mkForce because files declared through xdg.configFile come with
          # their own target default, which would otherwise conflict with ours
          home.file = lib.mapAttrs' (
            path: _: lib.nameValuePair path { target = lib.mkForce "${path}.hm"; }
          ) cfg;

          home.activation = lib.mapAttrs' (
            path: opts:
            lib.nameValuePair (entryName path) (
              lib.hm.dag.entryAfter [ "linkGeneration" ] ''
                $DRY_RUN_CMD rm -f "${toPath path}"
                $DRY_RUN_CMD install -m ${opts.mode} "${toPath path}.hm" "${toPath path}"
              ''
            )
          ) cfg;
        };
      }
    )
  ];
}
