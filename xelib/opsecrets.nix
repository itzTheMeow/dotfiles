{
  config,
  lib,
  hostname,
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
              default = "sops/${hostname}/${name}.${module.config.format}";
            };
            keys = lib.mkOption { type = lib.types.attrsOf lib.types.str; }; # secret URIs
          };
        }
      )
    );
    default = { };
  };
}
