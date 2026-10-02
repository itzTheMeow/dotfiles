# C/C++/C#
{
  pkgs,
  utils,
  ...
}:
{
  # "dotnet.dotnetPath" = "${pkgs.dotnet-sdk}/bin";
  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.ms-dotnettools.csharp # C#
    nixpkgs.ms-dotnettools.vscode-dotnet-runtime # .NET Install Tool
    nixpkgs.ms-vscode.cmake-tools # CMake Tools
    nixpkgs.ms-vscode.cpptools # C/C++
    marketplace.ms-vscode.cpp-devtools # C/C++ DevTools
  ];

  home-manager.importUser = [
    (utils.vscodeSettings {
      "[c]".editor.defaultFormatter = "ms-vscode.cpptools";
      "[cpp]".editor.defaultFormatter = "ms-vscode.cpptools";

      C_Cpp.default.compilerPath = "${pkgs.lib.getExe pkgs.gcc}";
      C_Cpp.default.includePath = [
        "${pkgs.lib.getDev pkgs.glibc}/include"
        "\${workspaceFolder}/**"
      ];
      cmake.cmakePath = "${pkgs.lib.getExe pkgs.cmake}";
      csharp.suppressDotnetInstallWarning = true;
      dotnet.formatting.organizeImportsOnFormat = true;
    })
    (utils.zedExtensions [
      "neocmake"
      "csharp"
    ])
  ];
}
