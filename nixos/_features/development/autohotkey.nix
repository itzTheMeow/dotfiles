{
  pkgs,
  utils,
  ...
}:
{
  programs.vscode.extensions = with pkgs.vscode-stores; [
    openvsx.mark-wiemer.vscode-autohotkey-plus-plus # AHK++
  ];

  home-manager.importUser = [
    (utils.zedExtensions [ "autohotkey" ])
  ];
}
