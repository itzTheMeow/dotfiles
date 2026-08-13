# swift/ios stuff
{ pkgs, ... }: {
  #TODO: swiftformat in settings
  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.llvm-vs-code-extensions.lldb-dap # LLDB DAP
    openvsx.vknabel.vscode-swiftformat # SwiftFormat
    openvsx.swiftlang.swift-vscode # Swift
    marketplace.ivhernandez.vscode-plist # Property List Editor
  ];
}
