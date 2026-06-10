{
  config,
  lib,
  modulesPath,
  ...
}:
let
  luksDevice = "cryptroot";
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # decrypted luks partiton
  boot.initrd.luks.devices.${luksDevice} = {
    device = "/dev/disk/by-uuid/bc39c959-30e1-4cbc-8664-def6a02336a6";
    allowDiscards = true;
  };
  persist.settings.device = "/dev/mapper/cryptroot";

  # boot partition
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/ADAA-A009";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    # {
    #   device = "/dev/disk/by-partuuid/d275409b-bb85-4bd3-b92d-3bb0274573a0";
    #   randomEncryption = {
    #     enable = true;
    #     # best based on performance
    #     cipher = "aes-xts-plain64";
    #     keySize = 512;
    #   };
    # }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
