{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      # development
      ## python
      python3
      python3Packages.numpy
      python3Packages.tkinter
    ];
    sessionVariables = {
      VIRTUAL_ENV_DISABLE_PROMPT = "1";
    };
  };
}
