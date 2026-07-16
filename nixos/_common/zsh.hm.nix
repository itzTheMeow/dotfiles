{ pkgs, ... }:
let
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
  };
}
