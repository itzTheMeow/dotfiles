{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    protobuf
  ];

  progarms.vscode.extensions = with pkgs.vscode-stores; [
    openvsx.drblury.protobuf-vsc # Protobuf VSC
  ];
}
