{ host, pkgs, ... }:
let
  initExtra = ''
    clear
    # source the secure shellfish file if present
    [ -f "$HOME/.shellfishrc" ] && source "$HOME/.shellfishrc"

    # run fastfetch outside of vscode
    [ "$TERM_PROGRAM" != "vscode" ] && ${pkgs.fastfetch}/bin/fastfetch
  '';
  shellHistorySize = 100000;
in
{
  programs = {
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
        path = "/home/${host.username}/.local/share/zsh_history/history";
      };
      setOptions = [ "INC_APPEND_HISTORY" ];
    };
    dircolors = {
      enable = true;
    };
  };
}
