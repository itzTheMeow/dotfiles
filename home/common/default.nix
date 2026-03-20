{
  hostname,
  osConfig,
  pkgs,
  xelib,
  xelpkgs,
  ...
}:
let
  initExtra = ''
    clear
    [ -f "$HOME/.profile_extra" ] && source $HOME/.profile_extra
    [ -f "$HOME/.shellfishrc" ] && source "$HOME/.shellfishrc"

    [ "$TERM_PROGRAM" != "vscode" ] && ${pkgs.fastfetch}/bin/fastfetch
  '';
  shellHistorySize = 100000;
in
{
  imports = [
    # import local config
    ../../local/home-manager.nix
    # various default programs
    ../programs/btop
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
      (writeShellScriptBin "0x0" (builtins.readFile ../../scripts/0x0.sh))
      (writeShellScriptBin "ffconcat" (builtins.readFile ../../scripts/ffconcat.sh))
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

      # short custom commands
      git-clear = ''
        git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
      '';
    };

    file.".config/ncdu/config".text = "--exclude pCloudDrive";
  };

  programs = {
    home-manager.enable = true;

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

  sops.age =
    if (osConfig.sops.secrets ? user_key) then
      { sshKeyPaths = [ osConfig.sops.secrets.user_key.path ]; }
    else
      # effectively disable
      { keyFile = "/dev/null"; };

  catppuccin = {
    flavor = xelib.globals.catppuccin.flavor;
    accent = xelib.globals.catppuccin.accent;
  };
}
