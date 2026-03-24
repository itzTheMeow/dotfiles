let
  opt =
    isNixOS:
    {
      config,
      lib,
      hostname,
      self,
      ...
    }:
    {
      options.sops.opSecrets = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }@module:
            {
              options = {
                format = lib.mkOption {
                  # type of file to use
                  type = lib.types.enum [
                    "yaml"
                    "json"
                    "dotenv"
                  ];
                  default = config.sops.defaultSopsFormat;
                };
                # file path, relative to the root of the repo
                path = lib.mkOption {
                  type = lib.types.str;
                  default = "sops/${hostname}/${lib.optionalString (!isNixOS) "user_"}${name}.${
                    # set extension to .env for dotenv
                    if module.config.format == "dotenv" then "env" else module.config.format
                  }";
                };
                # full path derived from the relative one, for ease of use
                fullPath = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = "${self}/${module.config.path}";
                };
                keys = lib.mkOption { type = lib.types.attrsOf lib.types.str; }; # secret URIs
              };
            }
          )
        );
        default = { };
      };
    };
in
{
  nixosModule = opt true;
  homeManagerModule = opt false;
}
