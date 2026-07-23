{
  osConfig,
  pkgs,
  xelib,
  xelpkgs,
  ...
}:
{
  imports = [
    # various default programs
    ../programs/fastfetch
    ../programs/oh-my-posh
    ../programs/rustic
  ];
  news.display = "silent";

  home = {
    stateVersion = "25.11"; # not to be changed
    # i insist
    enableNixpkgsReleaseCheck = false;

    packages = with pkgs; [
      # nix-related
      nh
      nix-your-shell

      # more complex tools
      speedtest-cli

      # temporary
      restic

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
      # custom packages
      xelpkgs.download-organizer
      xelpkgs.nx
    ];

    sessionVariables = xelib.globals.environment;

    shellAliases = {
      # basic
      ls = "ls --color=auto";
      la = "ls -A";
      ll = "ls -alF";
      grep = "grep --color=auto";
      txz = "tar -cJf";
      python = "python3";
      pip = "python3 -m pip";
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

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      settings = {
        user = {
          name = "Meow";
          email = "github@xela.codes";
        };

        pull.rebase = false;
      };
    };
  };

  sops.age =
    if ((osConfig.sops.groupPaths ? system) && (osConfig.sops.groupPaths.system ? user-key)) then
      { sshKeyPaths = [ osConfig.sops.groupPaths.system.user-key ]; }
    else
      # effectively disable
      { keyFile = "/dev/null"; };

  # catppuccin settings
  catppuccin = {
    enable = true;
    autoEnable = false;
    inherit (xelib.globals.catppuccin) accent flavor;
  };
}
