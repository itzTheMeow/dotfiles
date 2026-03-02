{
  pkgs,
  pkgs-unstable,
  ...
}:
let
  # read the current directory and map it to package names
  dirContents = builtins.readDir ./.;
  packageFiles = builtins.filter (
    # filter out valid packages (ignore this file)
    name: name != "default.nix" && pkgs.lib.hasSuffix ".nix" name && dirContents.${name} == "regular"
  ) (builtins.attrNames dirContents);
in
pkgs.lib.genAttrs (map (fn: pkgs.lib.removeSuffix ".nix" fn) packageFiles) (
  name: pkgs.callPackage ./${name}.nix { inherit pkgs-unstable; }
)
