{ config, lib, ... }:

let
  inherit (lib) mkOption types;
  cfg = config.sops;

  # env files are a whole secret file with the keys in
  envFiles = builtins.attrNames cfg.envFiles;
  envFileOpSecrets = builtins.listToAttrs (
    map (n: {
      name = n;
      value = {
        format = "dotenv";
        keys = cfg.envFiles.${n};
      };
    }) envFiles
  );
  envFileSecrets = builtins.listToAttrs (
    map (n: {
      name = n;
      value = {
        format = "dotenv";
        sopsFile = config.sops.opSecrets.${n}.fullPath;
        key = "";
      };
    }) envFiles
  );

  # create full secret name based on group/field
  groupSecretName = e: "${e.group}-${e.fieldName}";
  # normalize a field to the proper value/extra format
  normalizeField =
    field:
    if builtins.isString field then
      {
        value = field;
        extra = { };
      }
    else
      {
        value = field.value;
        extra = removeAttrs field [ "value" ];
      };

  # groups
  groupNames = builtins.attrNames cfg.groups;
  # flatten to a list of { group, fieldName, value, extra }
  allGroupEntries = lib.concatMap (
    group:
    let
      fields = cfg.groups.${group};
    in
    map (
      fieldName:
      let
        n = normalizeField fields.${fieldName};
      in
      {
        inherit group fieldName;
        inherit (n) value extra;
      }
    ) (builtins.attrNames fields)
  ) groupNames;

  groupOpSecrets = builtins.listToAttrs (
    map (group: {
      name = group;
      value.keys = lib.mapAttrs (_: field: (normalizeField field).value) cfg.groups.${group};
    }) groupNames
  );
  groupSecrets = builtins.listToAttrs (
    map (e: {
      # construct sops secrets
      name = groupSecretName e;
      value = e.extra // {
        sopsFile = config.sops.opSecrets.${e.group}.fullPath;
        key = e.fieldName;
      };
    }) allGroupEntries
  );
in
{
  options.sops = {
    envFiles = mkOption {
      type = types.attrsOf (types.attrsOf types.str);
      default = { };
      description = ''
        Attrset of SOPS dotenv files to generate from 1Password URIs.
        Each top-level key becomes an entry under `sops.opSecrets` and
        `sops.secrets` as an env file.
      '';
    };

    groups = mkOption {
      type = types.attrsOf (
        types.attrsOf (
          # fields can be either:
          #   - a plain "op://..." string, or
          #   - an attrset `{ value = "op://..."; <extra sops.secrets opts>; }`
          #     ex. { value = "op://Private/xxx"; owner = "xx"; }
          types.oneOf [
            types.str
            (types.attrsOf types.anything)
          ]
        )
      );
      default = { };
      description = ''
        Attrset of secret groups, for shorthand definition of secrets. Access paths via `config.sops.groupPaths.*.*`.
      '';
    };

    groupPaths = mkOption {
      type = types.attrsOf (types.attrsOf types.path);
      default = { };
      internal = true;
      description = ''
        Computed secret paths for `sops.groups`, matches the names in the group.
      '';
    };
  };

  config = {
    sops.opSecrets = envFileOpSecrets // groupOpSecrets;
    sops.secrets = envFileSecrets // groupSecrets;

    # set group paths to generated secret files
    sops.groupPaths = lib.foldl' (
      acc: e:
      lib.recursiveUpdate acc {
        ${e.group}.${e.fieldName} = config.sops.secrets.${groupSecretName e}.path;
      }
    ) { } allGroupEntries;
  };
}
