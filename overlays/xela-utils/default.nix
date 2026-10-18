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
        name = "u2c";
        text = ''
          base="''${U2C_BASE:-https://share.xela.codes}"
          url=""
          case "''${1:-}" in
            -d)
              if [[ $# -lt 2 ]]; then
                echo "u2c: -d requires a subpath" >&2
                exit 2
              fi
              url="$base/$2"
              shift 2
              ;;
            -d?*)
              url="$base/''${1#-d}"
              shift
              ;;
          esac
          case "''${1:-}" in
            http://* | https://*)
              if [[ -n "$url" ]]; then
                echo "u2c: -d and an explicit URL are mutually exclusive" >&2
                exit 2
              fi
              url="$1"
              shift
              ;;
          esac
          exec "${final.copyparty}/bin/u2c" -u "''${url:-''${U2C_URL:-$base/drop-200m}}" "$@"
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
