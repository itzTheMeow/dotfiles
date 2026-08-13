{ pkgs, ... }: {
  programs.vscode.extensions = with pkgs.vscode-stores; [
    openvsx.mark-wiemer.vscode-autohotkey-plus-plus # AHK++
  ];
}
