{ pkgs, hostname, ... }:
let
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];
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
      bashrcExtra = ''
        clear
        source ~/.profile_extra
      '';
    };
    zsh = {
      enable = true;
    };

    git = {
      enable = true;
      settings = {
        user = {
          name = "Meow";
          email = "github@xela.codes";
        };

        pull.rebase = false;

        # borrowed from https://github.com/bobvanderlinden/nixos-config/blob/0c09c5c162413816d3278c406d85c05f0010527c/home/default.nix#L938
        url."git@github.com:".insteadOf = [
          "https://github.com/"
          "github:"
        ];
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
