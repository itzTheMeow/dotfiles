{
  host,
  hostname,
  isNixOS,
  pkgs,
  xelib,
  ...
}:
let
  initExtra = ''
    clear
    [ -f "$HOME/.profile_extra" ] && source $HOME/.profile_extra
    [ -f "$HOME/.shellfishrc" ] && source "$HOME/.shellfishrc"

    [ "$TERM_PROGRAM" != "vscode" ] && ${pkgs.fastfetch}/bin/fastfetch
  '';
  shellHistorySize = 10000;
in
{
  imports = [
    # import local config
    ../../local/home-manager.nix
    # various default programs
    ../programs/btop
    ../programs/fastfetch
    ../programs/oh-my-posh
    ../programs/rclone
    ../programs/rustic
  ];
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
    username = host.username;
    homeDirectory = "/home/${host.username}";
    stateVersion = "25.05"; # not to be changed

    packages = with pkgs; [
      # nix-related
      nh
      nix-your-shell

      # basic dependencies
      cloc
      dnsutils
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
      (writeShellScriptBin "opunattended" (builtins.readFile ../../scripts/opunattended.sh))
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

      # short custom commands
      git-clear = ''
        git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
      '';
    };

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
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

        ${pkgs.nix-your-shell}/bin/nix-your-shell zsh | source /dev/stdin

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
    flavor = xelib.globals.catppuccin.flavor;
    accent = xelib.globals.catppuccin.accent;
  };
}

# [user]
# {{- if eq .box_group "nvstly" }}
# 	name = NVSTly
# 	email = team@nvst.ly
