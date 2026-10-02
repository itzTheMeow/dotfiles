{
  pkgs,
  utils,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    just
    just-lsp
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.nefrob.vscode-just-syntax # vscode-just
  ];

  home-manager.importUser = [
    (utils.zedExtensions [ "just" ])
  ];
}
