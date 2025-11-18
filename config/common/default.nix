{ pkgs, hostname, ... }:
let
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];

  initExtra = ''
    clear
    [ -f "$HOME/.profile_extra" ] && source $HOME/.profile_extra
    [ -f "$HOME/.shellfishrc" ] && source "$HOME/.shellfishrc"
  '';
in
{
  imports = optionalImport ../../local.nix;
  news.display = "silent";

  home = {
    stateVersion = "25.05"; # not to be changed

    packages = with pkgs; [
      # nix-related
      nh

      # basic dependencies
      ffmpeg
      renameutils
      unzip
      wget

      # for startup message
      lolcat

      # tools
      ncdu
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
      enable = true;
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

  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
}

# [user]
# {{- if eq .box_group "nvstly" }}
# 	name = NVSTly
# 	email = team@nvst.ly
