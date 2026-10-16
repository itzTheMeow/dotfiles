final: prev:
let
  inherit (final)
    lib
    writeShellApplication
    ;
in
{
  xela-utils = final.symlinkJoin {
    name = "xela-utils";
    paths = [
      (writeShellApplication {
        name = "0x0";
        runtimeInputs = [ final.curl ];
        text = ''
          curl -A "xela.codes/1.0.0" -F "file=@''${1:-}" https://0x0.st
        '';
      })
      (writeShellApplication {
        name = "ffconcat";
        runtimeInputs = [ final.ffmpeg-full ];
        # strip the shebang so writeShellApplication can supply its own
        text = builtins.concatStringsSep "\n" (
          lib.drop 1 (lib.splitString "\n" (builtins.readFile ./ffconcat.sh))
        );
      })
      (writeShellApplication {
        name = "nxr";
        runtimeInputs = [ final.nix ];
        text = ''
          if [ -z "''${1:-}" ]; then
            nix run .
          else
            target="$1"
            shift
            nix run ".#$target" -- "$@"
          fi
        '';
      })
      (writeShellApplication {
        name = "nxb";
        runtimeInputs = [ final.nix ];
        text = ''
          if [ -z "''${1:-}" ]; then
            nix build .
          else
            target="$1"
            shift
            nix build ".#$target" -- "$@"
          fi
        '';
      })
      (writeShellApplication {
        name = "git-clear";
        runtimeInputs = [
          final.gawk
          final.gnugrep
          final.git
        ];
        text = ''
          git fetch -p
          while read -r branch; do
            git branch -D "$branch"
          done < <(git branch -vv | grep ': gone]' | awk '{print $1}')
        '';
      })
    ];
  };
}
