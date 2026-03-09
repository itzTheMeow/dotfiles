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
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/mapper/luks-1aa6d9d6-e0c0-4882-94e6-608ecf8fd264";
    fsType = "ext4";
  };
  boot.initrd.luks.devices."luks-1aa6d9d6-e0c0-4882-94e6-608ecf8fd264".device =
    "/dev/disk/by-uuid/1aa6d9d6-e0c0-4882-94e6-608ecf8fd264";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/F50A-91A2";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/mapper/luks-5e7badd8-c615-499f-a505-97bc1bdf41d7";
      randomEncryption = {
        enable = true;
        # best based on performance
        cipher = "aes-xts-plain64";
        keySize = 256;
      };
    }
  ];
  boot.initrd.luks.devices."luks-5e7badd8-c615-499f-a505-97bc1bdf41d7".device =
    "/dev/disk/by-uuid/5e7badd8-c615-499f-a505-97bc1bdf41d7";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
