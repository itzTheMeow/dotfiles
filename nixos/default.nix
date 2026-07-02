hostname:
let
  hostDir = ./${hostname};
  entries = builtins.readDir hostDir;
in
{
  imports = [
    # import local nixosconfig
    ../local/nixos.nix
    ./common.nix
  ]
  # import all .nix files in the directory
  ++ map (name: hostDir + "/${name}") (
    builtins.filter (
      name:
      # import directories
      entries.${name} == "directory"
      || (
        # or .nix files
        entries.${name} == "regular"
        && builtins.match ".*\\.nix" name != null
        # ignore features file as that is imported later
        && name != "features.nix"
      )
    ) (builtins.attrNames entries)
  )
  # import all enabled features
  ++ map (feature: ./_features/${feature}) (import (hostDir + "/features.nix"));
}
