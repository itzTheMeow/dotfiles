{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "88x2bu"
  ];
  boot.extraModulePackages = [
    # for wifi adapter
    config.boot.kernelPackages.rtl88x2bu
  ];

  fileSystems."/" = {
    device = "/dev/mapper/luks-4bb005d6-36e7-4dcb-a42c-1e2237953f99";
    fsType = "ext4";
  };

  boot.initrd.luks.devices."luks-4bb005d6-36e7-4dcb-a42c-1e2237953f99".device =
    "/dev/disk/by-uuid/4bb005d6-36e7-4dcb-a42c-1e2237953f99";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/ADAA-A009";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/d275409b-bb85-4bd3-b92d-3bb0274573a0";
      randomEncryption = {
        enable = true;
        # best based on performance
        cipher = "aes-xts-plain64";
        keySize = 512;
      };
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
