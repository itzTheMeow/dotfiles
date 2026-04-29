{
  config,
  lib,
  ...
}:

let
  inherit (lib) mkOption types;
  cfg = config.sops;
in
{
  options.sops.envFiles = mkOption {
    type = types.attrsOf (types.attrsOf types.str);
    default = { };
    description = ''
      Attrset of SOPS dotenv files to generate from 1Password URIs.
      Each top-level key becomes an entry under `sops.opSecrets` and
      `sops.secrets` as an env file.
    '';
  };

  config =
    let
      names = builtins.attrNames cfg.envFiles;
    in
    {
      # create opsecrets entries
      sops.opSecrets = builtins.listToAttrs (
        map (n: {
          name = n;
          value = {
            format = "dotenv";
            keys = cfg.envFiles.${n};
          };
        }) names
      );
      # then create sops secret files
      sops.secrets = builtins.listToAttrs (
        map (n: {
          name = n;
          value = {
            format = "dotenv";
            sopsFile = config.sops.opSecrets.${n}.fullPath;
            key = "";
          };
        }) names
      );
    };
}
