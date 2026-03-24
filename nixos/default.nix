hostname:
let
  hostDir = ./${hostname};
  entries = builtins.readDir hostDir;
in
{
  imports = [
    ./common
  ]
  ++ builtins.map (name: hostDir + "/${name}") (
    builtins.filter (
      name:
      entries.${name} == "directory"
      || (entries.${name} == "regular" && builtins.match ".*\\.nix" name != null)
    ) (builtins.attrNames entries)
  );
}
