{
  pkgs,
  hostname,
  utils,
  ...
}:
let
  initExtra = ''
    clear
    [ -f "$HOME/.profile_extra" ] && source $HOME/.profile_extra
    [ -f "$HOME/.shellfishrc" ] && source "$HOME/.shellfishrc"

    export BUN_INSTALL="$HOME/.bun" 
    export PATH="$BUN_INSTALL/bin:$PATH" 
  '';
in
{
  imports = [
    ../programs/btop
  ]
  ++ utils.optionalImport ../../local.nix;
  news.display = "silent";

  home = {
    stateVersion = "25.05"; # not to be changed

    packages = with pkgs; [
      # nix-related
      nh

      # basic dependencies
      ffmpeg
      ncdu
      renameutils
      tree
      unzip
      wget

      # for startup message
      lolcat

      # more complex tools
      ntfy-sh
      rclone
      rustic
      speedtest-cli
    ];

    shellAliases = {
      # basic
      la = "ls -A";
      ll = "ls -alF";
      txz = "tar -cJf";
      python = "python3";
      pip = "python3 -m pip";
      qmv = "qmv -ospaces"; # use spaces for qmv

      # short custom commands
      git-clear = ''
        git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
      '';
      "0x0" = builtins.toString ../../scripts/0x0;
      # utility to manage nix configuration
      nx = ''HOSTNAME=${hostname} ${builtins.toString ../../scripts/nx}'';
    };

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
  };

  programs = {
    home-manager.enable = true;

    bash = {
      enable = true;
      bashrcExtra = initExtra;
    };
    zsh = {
      initContent = initExtra;
    };

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

  programs.onepassword-secrets = {
    enable = true;
    tokenFile = "/etc/opnix-token";

    secrets = {
      immichKey = {
        reference = "op://Private/Immich/API Keys/CLI";
        mode = "0400";
      };
    };
  };

  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
}

# [user]
# {{- if eq .box_group "nvstly" }}
# 	name = NVSTly
# 	email = team@nvst.ly
