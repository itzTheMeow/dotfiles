{
  pkgs,
  utils,
  ...
}:
{
  environment = {
    systemPackages = with pkgs; [
      python3
      python3Packages.numpy
      python3Packages.tkinter
    ];
    variables = {
      VIRTUAL_ENV_DISABLE_PROMPT = "1";
    };
  };

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.ms-python.black-formatter # Black Formatter
    nixpkgs.ms-python.isort # isort
    nixpkgs.ms-python.debugpy # Python Debugger
    nixpkgs.ms-python.python # Python
    nixpkgs.ms-python.vscode-pylance # Pylance
    openvsx.ms-python.vscode-python-envs # Python Environments
  ];

  home-manager.importUser = [
    (utils.vscodeSettings {
      "[python]".editor.defaultFormatter = "ms-python.black-formatter";

      python.analysis.autoImportCompletions = true;
      python.defaultInterpreterPath = "python3";
    })
    (_: {
      home.shellAliases = {
        python = "python3";
        pip = "python3 -m pip";
      };
    })
  ];
}
