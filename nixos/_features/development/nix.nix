{
  pkgs,
  utils,
  ...
}:
let
  nixfmt = "${pkgs.lib.getExe pkgs.nixfmt}";
in
{
  environment.systemPackages = [ pkgs.nixfmt ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.jnoortheen.nix-ide # Nix IDE
  ];

  home-manager.importUser = [
    (utils.vscodeSettings {
      "[nix]".editor.defaultFormatter = "jnoortheen.nix-ide";

      nix.enableLanguageServer = true;
      nix.serverPath = "${pkgs.lib.getExe pkgs.nixd}";
      nix.serverSettings.nixd.formatting.command = [ nixfmt ];
    })
    (utils.zedExtensions [ "nix" ])
    (utils.zedSettings {
      languages.Nix = {
        language_servers = [
          "nixd"
          "!nil"
        ];
        formatter.external.command = nixfmt;
      };
    })
    (_: {
      # required for the LSP
      programs.zed-editor.extraPackages = [ pkgs.nixd ];
    })
  ];
}
