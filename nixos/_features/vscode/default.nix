{ pkgs, pkgs-unstable, ... }: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode-fhs;
  };
  services.vscode-server = {
    enable = true;
    installPath = "$HOME/.vscode";
  };

  # temporary
  environment.systemPackages = [ pkgs-unstable.kilo ];
}
