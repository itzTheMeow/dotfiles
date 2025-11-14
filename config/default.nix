{ pkgs, ... }:
let
  shellAliases = {
    # basic
    ll = "ls -alF";
    la = "ls -A";
    l = "ls -CF";
    txz = "tar -cJf";
    python = "python3";
    pip = "python3 -m pip";

    # short custom commands
    git-clear = ''
      git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
    '';
    nixup = ''
      current_flake=$(nixup_currentflake)
      home-manager switch --flake ~/.dotfiles#$current_flake
    '';
  };
in
{
  news.display = "silent";

  home = {
    stateVersion = "23.11"; # not to be changed

    packages = with pkgs; [
      # obviously needed
      home-manager

      # basic dependencies
      ffmpeg
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

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
  };

  programs = {
    bash = {
      enable = true;
      bashrcExtra = ''
        source ~/.profile_extra
        0x0() { curl -F "file=@$1" https://0x0.st; }
      '';
      inherit shellAliases;
    };
    zsh = {
      enable = true;
      inherit shellAliases;
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
}

# [user]
# {{- if eq .box_group "nvstly" }}
# 	name = NVSTly
# 	email = team@nvst.ly
