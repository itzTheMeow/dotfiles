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
    # for kitty ssh serverside support
    kitty
  ];
}
