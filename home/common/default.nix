{
  pkgs,
  xelpkgs,
  ...
}:
{
  imports = [
    # various default programs
    ../programs/rustic
  ];
  news.display = "silent";

  home = {
    packages = with pkgs; [
      # more complex tools
      speedtest-cli

      # custom scripts
      (writeShellScriptBin "0x0" ''curl -A "xela.codes/1.0.0" -F "file=@$1" https://0x0.st'')
      (writeShellScriptBin "ffconcat" (builtins.readFile ../../scripts/ffconcat.sh))
      (writeShellScriptBin "nxr" ''
        if [ -z "$1" ]; then
          nix run .
        else
          target="$1"
          shift
          nix run ".#$target" -- "$@"
        fi
      '')
      (writeShellScriptBin "nxb" ''
        if [ -z "$1" ]; then
          nix build .
        else
          target="$1"
          shift
          nix build ".#$target" -- "$@"
        fi
      '')
      # custom packages
      xela-download-organizer
      xelpkgs.nx
    ];

    shellAliases = {
      # basic
      ls = "ls --color=auto";
      la = "ls -A";
      ll = "ls -alF";
      grep = "grep --color=auto";
      txz = "tar -cJf";
      qmv = "qmv -ospaces"; # use spaces for qmv
      cdtemp = "cd $(mktemp -d) && pwd";

      # shortcuts
      sc = "sudo systemctl";
      scu = "systemctl --user";

      # short custom commands
      git-clear = ''
        git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
      '';
    };
  };
}
