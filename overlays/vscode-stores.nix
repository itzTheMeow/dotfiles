# shorthand for the various vscode extensions
final: prev: {
  vscode-stores = {
    nixpkgs = final.vscode-extensions;
    openvsx = final.nix-vscode-extensions.open-vsx;
    marketplace = final.nix-vscode-extensions.vscode-marketplace;
  };
}
