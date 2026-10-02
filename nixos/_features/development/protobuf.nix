{
  pkgs,
  utils,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    protobuf
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    openvsx.drblury.protobuf-vsc # Protobuf VSC
  ];

  home-manager.importUser = [
    (utils.vscodeSettings {
      "[proto]".editor.defaultFormatter = "DrBlury.protobuf-vsc";
      "[proto3]".editor.defaultFormatter = "DrBlury.protobuf-vsc";

      protobuf.formatOnSave = true;
    })
    (utils.zedExtensions [ "proto" ])
  ];
}
