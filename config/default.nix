{ pkgs, ... }:
let
  shellAliases = {
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
  home = {
    stateVersion = "23.11"; # not to be changed

    packages = with pkgs; [
      # obviously needed
      home-manager

      ncdu
      rclone
      rustic
      speedtest-cli
    ];

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
  };

  programs = {
    bash = {
      enable = true;
      bashrcExtra = "source ~/.profile_extra";
      inherit shellAliases;
    };
    zsh = {
      enable = true;
      inherit shellAliases;
    };

    git = {
      enable = true;
      userName = "Meow";
      userEmail = "github@xela.codes";
      extraConfig = {
        pull.rebase = false;
      };
    };
  };
}

# [user]
# {{- if eq .box_group "nvstly" }}
# 	name = NVSTly
# 	email = team@nvst.ly
# {{- end }}
# {{- if not .headless }}
# {{- if not .headless }}
# [gpg]
# 	format = ssh
# [gpg "ssh"]
# {{- if eq .chezmoi.os "darwin" }}
# 	program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
# {{- else if eq .chezmoi.os "linux" }}
# 	program = "/opt/1Password/op-ssh-sign"
# {{- end }}
# [commit]
# 	gpgsign = true
# {{- end }}
