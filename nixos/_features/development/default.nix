# individual programming language definitions
# languages are defined by their "base" (js instead of ts, dart instead of flutter)
# they install themselves, vscode extensions, and possible cache paths
# currently there is no way to enable specific toolchains for specific hosts but this may be useful in the future
{ xelib, ... }: {
  imports = xelib.umport {
    path = ./.;
    exclude = [ ./default.nix ];
  };
}
