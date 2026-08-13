{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    mcp-nixos
    nixd
    nixfmt
  ];

  programs.vscode.extensions = [
    pkgs.vscode-extensions.jnoortheen.nix-ide # Nix IDE
  ];
}
