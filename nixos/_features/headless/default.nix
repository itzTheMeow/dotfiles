# any device without a gui
{ ... }:
{
  # just gets default systemd boot with a quick timeout
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };
}
