{
  config,
  host,
  lib,
  ...
}@inputs:
let
  cfg = config.home-manager;
in
{
  options.home-manager = {
    imports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.path);
      default = { };
      description = "Set of usernames and home-manager modules to import.";
    };
    importUser = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "home-manager extension modules to import for the host user.";
    };
    importAll = lib.mkOption {
      type = lib.types.listOf lib.types.path;
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
    _: files: hm:
    lib.mkMerge (map (file: import file (inputs // { inherit hm; })) files)
  ) cfg.imports;
}
