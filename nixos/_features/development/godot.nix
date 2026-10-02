{
  pkgs,
  utils,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    #TODO:26.11 flip to stable
    unstable.godot
    gdtoolkit_4
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.geequlim.godot-tools # Godot Tools
  ];

  home-manager.importUser = [
    (utils.zedExtensions [ "gdscript" ])
  ];
}
