final: prev:
let
  inherit (final) lib;

in
{
  xela-codearchive = final.writeShellApplication {
    name = "codearchive";
    runtimeInputs = [
      final.coreutils
      final.findutils
      final.gnugrep
      final.gnused
      final.python3Packages.pygments # pygmentize
      final.wkhtmltopdf
    ];
    # preserve the script's original lax error handling
    bashOptions = [ ];
    excludeShellChecks = [ "SC2129" ];
    text = builtins.concatStringsSep "\n" (
      lib.drop 1 (lib.splitString "\n" (builtins.readFile ./codearchive.sh))
    );
    meta.mainProgram = "codearchive";
  };
}
