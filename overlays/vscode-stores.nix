# shorthand for the various vscode extensions
final: prev: {
  vscode-stores = {
    # officially packaged extensions
    nixpkgs = final.vscode-extensions;
    # on openvsx but not packaged natively
    openvsx = final.nix-vscode-extensions.open-vsx;
    # as a last resort use marketplace
    marketplace = final.nix-vscode-extensions.vscode-marketplace;
  };
}
