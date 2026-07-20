{
  config,
  host,
  hostname,
  lib,
  pkgs,
  xelib,
  ...
}@inputs:
let
  inherit (lib) mkOption types;

  cfg = config.home-manager;

  # either a path to a home-manager module or a function that is the module itself
  hmModuleEntry = types.oneOf [
    types.path
    (types.functionTo types.attrs)
  ];
in
{
  options.home-manager = {
    imports = mkOption {
      type = types.attrsOf (types.listOf hmModuleEntry);
      default = { };
      description = "Set of usernames and home-manager modules to import.";
    };
    importUser = mkOption {
      type = types.listOf hmModuleEntry;
      default = [ ];
      description = "home-manager extension modules to import for the host user.";
    };
    importAll = mkOption {
      type = types.listOf hmModuleEntry;
      default = [ ];
      description = "home-manager extension modules to import for both the host user and root.";
    };
  };

  # map shortcuts to actual import username pairs
  config.home-manager.imports = lib.mkMerge [
    (lib.mkIf (cfg.importUser != [ ]) {
      ${host.username} = cfg.importUser;
    })
    (lib.mkIf (cfg.importAll != [ ]) {
      root = cfg.importAll;
      ${host.username} = cfg.importAll;
    })
  ];

  # map the usernames to module imports and expose `hm` as the hm inputs
  config.home-manager.users = lib.mapAttrs (
    _: entries: hm:
    lib.mkMerge (
      map (
        entry:
        # call the module function
        if lib.isFunction entry then
          entry hm
        # otherwise import it with the hm parameter added
        else
          import entry (inputs // { inherit hm; })
      ) entries
    )
  ) cfg.imports;
}
