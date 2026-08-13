{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    just
    just-lsp
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.nefrob.vscode-just-syntax # vscode-just
  ];
}
