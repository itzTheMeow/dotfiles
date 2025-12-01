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

    # temporary
    export BUN_INSTALL="$HOME/.bun" 
    export PATH="$BUN_INSTALL/bin:$PATH"

    [ "$TERM_PROGRAM" != "vscode" ] && ${pkgs.fastfetch}/bin/fastfetch
  '';
  shellHistorySize = 10000;
in
{
  imports = [
    ../programs/btop
    ../programs/fastfetch
    ../programs/oh-my-posh
  ]
  ++ utils.optionalImport ../../local.nix;
  news.display = "silent";

  nix = {
    package = pkgs.nix;
    settings.experimental-features = "nix-command flakes";
  };

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

      # temporary
      restic
    ];

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

      # short custom commands
      git-clear = ''
        git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
      '';
      # utility to manage nix configuration
      "nx" = ''HOSTNAME=${hostname} ${builtins.toString ../../scripts/nx.sh}'';
      # other bash scripts
      "0x0" = builtins.toString ../../scripts/0x0.sh;
      "codearchive" = builtins.toString ../../scripts/codearchive.sh;
      "ffconcat" = builtins.toString ../../scripts/ffconcat.sh;
    };

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
    file.".config/rustic".source = ../../rustic;
  };

  programs = {
    home-manager.enable = true;
    opinject.cleanupBackups = true;

    bash = {
      enable = true;
      bashrcExtra = ''
        shopt -s histappend
        shopt -s checkwinsize
        ${initExtra}
      '';
      historyControl = [ "ignoreboth" ];
      historyFileSize = shellHistorySize;
      historySize = shellHistorySize;
    };
    zsh = {
      enable = true;
      initContent = ''
        bindkey  "^[[H"   beginning-of-line
        bindkey  "^[[F"   end-of-line
        bindkey  "^[[3~"  delete-char

        ${initExtra}
      '';
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      history = {
        size = shellHistorySize;
        save = shellHistorySize;
        share = true;
        append = true;
      };
      setOptions = [ "INC_APPEND_HISTORY" ];
    };
    dircolors = {
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
