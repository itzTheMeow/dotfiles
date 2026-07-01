# any device without a gui
{ pkgs, ... }:
{
  # just gets default systemd boot with a quick timeout
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };

  environment.systemPackages = with pkgs; [
    # we can install the cli via nix for headless machines because it doesnt need desktop integration
    _1password-cli
    # for kitty ssh serverside support
    kitty
  ];
}
