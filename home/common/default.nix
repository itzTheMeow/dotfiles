{
  globals,
  isNixOS,
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
    ../programs/rclone
  ]
  ++ utils.optionalImport ../../local.nix;
  news.display = "silent";

  # apply only on standalone home-manager
  nix = (
    if !isNixOS then
      {
        package = pkgs.nix;
        settings.experimental-features = "nix-command flakes";
        settings.auto-optimise-store = true;
      }
    else
      { }
  );

  home = {
    stateVersion = "25.05"; # not to be changed

    packages = with pkgs; [
      # nix-related
      nh

      # basic dependencies
      cloc
      ffmpeg
      git
      jq
      killport
      ncdu
      renameutils
      tree
      unzip
      wget

      # more complex tools
      ntfy-sh
      rustic
      speedtest-cli
      yt-dlp

      # temporary
      restic

      # custom scripts
      (writeShellScriptBin "0x0" (builtins.readFile ../../scripts/0x0.sh))
      (writeShellScriptBin "ffconcat" (builtins.readFile ../../scripts/ffconcat.sh))
      (writeShellScriptBin "nx" ''
        export HOSTNAME="${hostname}"
        ${builtins.readFile ../../scripts/nx.sh}
      '')
      # custom packages
      (buildGoModule {
        name = "download-organizer";
        src = ../../go/download-organizer;
        vendorHash = null;
      })
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
    flavor = globals.catppuccin.flavor;
    accent = globals.catppuccin.accent;
  };
}

# [user]
# {{- if eq .box_group "nvstly" }}
# 	name = NVSTly
# 	email = team@nvst.ly
