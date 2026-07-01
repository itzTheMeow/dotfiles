# any "workstation" (laptop/pc/etc) thats not a server/tv
_: {
  imports = [
    ./hardware-wifi-adapter.nix
  ];
  # enable document printing
  services.printing.enable = true;
}
