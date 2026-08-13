# minecraft-related development tools
{ pkgs, ... }: {
  programs.vscode.extensions = with pkgs.vscode-stores; [
    marketplace.nickac.skriptinsight # Skript + SkriptInsight
  ];
}
