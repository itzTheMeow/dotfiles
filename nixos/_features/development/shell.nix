# various development-related utilities for shell checking
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    shellcheck
    shfmt
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.mkhl.shfmt # shfmt
    nixpkgs.timonwong.shellcheck # ShellCheck
  ];
}
