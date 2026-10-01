# minecraft-related development tools
{
  xelib,
  pkgs,
  ...
}:
{
  programs.vscode.extensions = with pkgs.vscode-stores; [
    marketplace.nickac.skriptinsight # Skript + SkriptInsight
  ];

  home-manager.importUser = [
    (xelib.zedExtensions [ "skript" ])
  ];
}
