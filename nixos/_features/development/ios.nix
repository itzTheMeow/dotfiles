# swift/ios stuff
{
  xelib,
  pkgs,
  ...
}:
{
  #TODO: swiftformat in settings
  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.llvm-vs-code-extensions.lldb-dap # LLDB DAP
    openvsx.vknabel.vscode-swiftformat # SwiftFormat
    openvsx.swiftlang.swift-vscode # Swift
    marketplace.ivhernandez.vscode-plist # Property List Editor
  ];

  home-manager.importUser = [
    (xelib.zedExtensions [ "swift" ])
  ];
}
