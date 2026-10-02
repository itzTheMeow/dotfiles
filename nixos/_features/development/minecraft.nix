# minecraft-related development tools
{
  pkgs,
  utils,
  ...
}:
{
  programs.vscode.extensions = with pkgs.vscode-stores; [
    marketplace.nickac.skriptinsight # Skript + SkriptInsight
  ];

  home-manager.importUser = [
    (utils.zedExtensions [ "skript" ])
  ];
}
