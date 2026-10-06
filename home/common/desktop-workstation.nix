{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      # development
      ## javascript
      unstable.bun
      deno
      nodejs_24
      pnpm_10
      tsx

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
