{ pkgs, pkgs-unstable, ... }: {
  environment.systemPackages =
    #TODO:26.11 flip to stable
    (with pkgs-unstable; [ godot ])
    ++ (with pkgs; [
      gdtoolkit_4
    ]);

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.geequlim.godot-tools # Godot Tools
  ];
}
