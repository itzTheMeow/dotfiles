{ pkgs, ... }:
{
  packages = with pkgs; [

  ];

  home = {
    shellAliases = {
      # make vscode short command
      code = "open -a /Applications/Visual\ Studio\ Code.app";
      # remove quarantine status from files
      unquarantine = "xattr -r -d com.apple.quarantine";
    };
  };

  programs.zsh.enable = true;
}
