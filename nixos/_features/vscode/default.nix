{ pkgs, ... }: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode-fhs;
  };
  services.vscode-server.enable = true;
}
