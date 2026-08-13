# C/C++/C#
{ pkgs, ... }: {
  # "dotnet.dotnetPath" = "${pkgs.dotnet-sdk}/bin";
  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.ms-dotnettools.csharp # C#
    nixpkgs.ms-dotnettools.vscode-dotnet-runtime # .NET Install Tool
    nixpkgs.ms-vscode.cmake-tools # CMake Tools
    nixpkgs.ms-vscode.cpptools # C/C++
    marketplace.ms-vscode.cpp-devtools # C/C++ DevTools
  ];
}
