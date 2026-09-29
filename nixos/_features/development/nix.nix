{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nixd
    nixfmt
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.jnoortheen.nix-ide # Nix IDE
  ];
}
