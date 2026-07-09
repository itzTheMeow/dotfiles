# extra config/drivers for usb wifi adapters
{ config, ... }:
{
  boot.extraModulePackages = [
    config.boot.kernelPackages.rtl88x2bu # cudy
    config.boot.kernelPackages.rtl8821cu # odroid
  ];
  boot.kernelModules = [
    "88x2bu"
    "8821cu"
  ];
}
