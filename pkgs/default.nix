{
  pkgs,
  pkgs-unstable,
  ...
}:
let
  # read the current directory and map it to package names, supporting both
  # bare `<package>.nix` files and `<package>/default.nix` directories
  dirContents = builtins.readDir ./.;
  entries = builtins.filter (e: e != null) (
    map (
      name:
      if name != "default.nix" && dirContents.${name} == "regular" && pkgs.lib.hasSuffix ".nix" name then
        {
          pname = pkgs.lib.removeSuffix ".nix" name;
          file = ./. + "/${name}";
        }
      else if
        dirContents.${name} == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
      then
        {
          pname = name;
          file = ./. + "/${name}/default.nix";
        }
      else
        null
    ) (builtins.attrNames dirContents)
  );
  specialArgs = {
    inherit pkgs-unstable xelpkgs;
  };
  xelpkgs = pkgs.lib.listToAttrs (
    map (e: {
      name = e.pname;
      value = pkgs.callPackage e.file (
        builtins.intersectAttrs (builtins.functionArgs (import e.file)) specialArgs
      );
    }) entries
  );
in
xelpkgs
