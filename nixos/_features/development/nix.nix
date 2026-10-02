{
  pkgs,
  utils,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    nixd
    nixfmt
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.jnoortheen.nix-ide # Nix IDE
  ];

  home-manager.importUser = [
    (utils.vscodeSettings {
      "[nix]".editor.defaultFormatter = "jnoortheen.nix-ide";

      nix.enableLanguageServer = true;
      nix.serverSettings.nixd.formatting.command = [ "${pkgs.lib.getExe pkgs.nixfmt}" ];
    })
    (utils.zedExtensions [ "nix" ])
  ];
}
