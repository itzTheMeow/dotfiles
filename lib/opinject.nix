{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.home.file;
in
{
  options.home.file = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { ... }:
        {
          options.opinject = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to run op inject on this file.";
          };
        }
      )
    );
  };

  config = {
    warnings = lib.flatten (
      lib.mapAttrsToList (
        name: fileCfg:
        if fileCfg.opinject && !fileCfg.force then
          [ "opinject enabled for ${name} but force is not enabled. This might cause conflicts." ]
        else
          [ ]
      ) cfg
    );

    home.activation.opinject = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        opFiles = lib.filterAttrs (_: f: f.opinject) cfg;
        opPkg = "${pkgs._1password-cli}/bin/op";
        mkOpCommand =
          name: file:
          let
            target = "${config.home.homeDirectory}/${file.target}";
          in
          ''
            if [ -e "${target}" ]; then
              echo "Injecting secrets into ${target}"
              if ! $OP_CMD inject --force -i "${target}" -o "${target}" > /dev/null; then
                echo "Failed to inject secrets into ${target}"
              fi
            else
              echo "Target file ${target} does not exist, skipping op inject"
            fi
          '';
      in
      ''
        if [ -x "/usr/local/bin/op" ]; then
          OP_CMD="/usr/local/bin/op"
        else
          OP_CMD="${opPkg}"
        fi
      ''
      + (lib.concatStringsSep "\n" (lib.mapAttrsToList mkOpCommand opFiles))
    );
  };
}
