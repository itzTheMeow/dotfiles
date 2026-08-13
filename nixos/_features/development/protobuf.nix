{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    protobuf
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    openvsx.drblury.protobuf-vsc # Protobuf VSC
  ];
}
