{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      # we can install the cli via nix for headless machines because it doesnt need desktop integration
      _1password-cli
    ];
  };
}
