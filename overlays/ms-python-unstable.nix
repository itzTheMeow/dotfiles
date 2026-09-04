#TODO:26.11 drop when nixpkgs has ms-python 2026.6.0+
final: prev: {
  vscode-extensions = prev.vscode-extensions // {
    ms-python = final.unstable.vscode-extensions.ms-python;
  };
}
