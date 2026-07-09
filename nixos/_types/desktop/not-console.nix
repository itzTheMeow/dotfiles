# any desktop that isnt a console
{ ... }: {
  imports = [ ./hardware-wifi-adapter.nix ];

  # enable document printing
  services.printing.enable = true;
}
