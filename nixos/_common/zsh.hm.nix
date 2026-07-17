{
  config,
  hm,
  host,
  pkgs,
  xelib,
  ...
}:
let
  # if current user is the "main" account and should host the daemon
  atuinEnableDaemon = hm.config.home.username == host.username;

  initExtra = ''
    clear
    # source the secure shellfish file if present
    [ -f "$HOME/.shellfishrc" ] && source "$HOME/.shellfishrc"

    # run fastfetch outside of vscode
    [ "$TERM_PROGRAM" != "vscode" ] && ${pkgs.fastfetch}/bin/fastfetch
  '';
in
{
  programs = {
    bash = {
      enable = true;
      bashrcExtra = initExtra;
      historyControl = [ "ignoreboth" ];
      historyFileSize = 0;
      historySize = 100;
      # auto update window size variables
      shellOptions = [ "checkwinsize" ];
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
        # actual zsh history is (mostly) disabled so atuin can do its thing
        size = 100;
        save = 0;
        share = false;
      };
    };
    dircolors.enable = true;

    atuin = {
      enable = true;
      daemon.enable = atuinEnableDaemon;
      # https://github.com/atuinsh/atuin/pull/2945
      # apply patch to add ATUIN_DATA_DIR support so we can relocate it
      package = pkgs.atuin.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (pkgs.fetchpatch {
            url = "https://github.com/atuinsh/atuin/commit/6e01ff990f223d2c0ba63742215f2af2111b87ef.patch";
            hash = "sha256-R4Oo7JgKeYwvp6Wv2YM8CZwAMsx9qy2obAWqIu9azGk=";
          })
        ];
      });
      settings = {
        key_path = config.sops.secrets.atuin-key.path;
        auto_sync = true;
        update_check = false;
        sync_address = xelib.apps.atuin-server.url;
        sync_frequency = "10s";
        search_mode = "daemon-fuzzy";
        filter_mode_shell_up_key_binding = "host"; # default to current host history
        workspaces = true; # enable git repo filtering
        enter_accept = true;

        # configure non-main daemons to use the main one
        daemon = hm.lib.mkIf (!atuinEnableDaemon) {
          enabled = true;
          socket_path = "/run/user/1000/atuin.sock";
        };
      };
      forceOverwriteSettings = true;
    };
  };

  systemd.user.services.atuin-daemon.Service.Environment = [
    "ATUIN_DATA_DIR=${config.environment.variables.ATUIN_DATA_DIR}"
  ];
}
