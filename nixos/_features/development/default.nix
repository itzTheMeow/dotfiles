# individual programming language definitions
# languages are defined by their "base" (js instead of ts, dart instead of flutter)
# they install themselves, vscode extensions, and possible cache paths
# currently there is no way to enable specific toolchains for specific hosts but this may be useful in the future
{
  lib,
  xelib,
  ...
}:
let
  # various utilities for the imported files to use
  utils = {
    vscodeSettings = sett: _: { programs.vscode.profiles.default.userSettings = sett; };
    zedExtensions = exts: _: { programs.zed-editor.extensions = exts; };
    zedSettings = sett: _: { programs.zed-editor.userSettings = sett; };
  };

  # nix magic to inject the utils into each file
  withUtils =
    file:
    args@{ config, ... }:
    let
      module = import file;
      resolved = lib.mapAttrs (
        name: _: if args ? ${name} then args.${name} else config._module.args.${name}
      ) (lib.removeAttrs (lib.functionArgs module) [ "utils" ]);
    in
    if lib.isFunction module then module (args // resolved // { inherit utils; }) else module;
in
{
  imports = map withUtils (
    xelib.umport {
      path = ./.;
      exclude = [ ./default.nix ];
    }
  );
}
