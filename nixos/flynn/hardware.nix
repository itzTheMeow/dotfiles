{
  config,
  lib,
  modulesPath,
  ...
}:
let
  luksDevice = "cryptroot";
  mkSubvol = name: compression: [
    "subvol=${name}"
    compression
    "noatime" # dont need access time
  ];
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
  boot.initrd.supportedFilesystems = [ "btrfs" ];

  # decrypted luks partiton
  boot.initrd.luks.devices.${luksDevice} = {
    device = "/dev/disk/by-uuid/bc39c959-30e1-4cbc-8664-def6a02336a6";
    allowDiscards = true;
  };

  # boot partition
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/ADAA-A009";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/" = {
    device = "/dev/mapper/${luksDevice}";
    fsType = "btrfs";
    options = mkSubvol "root" "compress=zstd:1";
    neededForBoot = true;
  };
  fileSystems."/nix" = {
    device = "/dev/mapper/${luksDevice}";
    fsType = "btrfs";
    options = mkSubvol "nix" "compress-force=zstd:5";
    neededForBoot = true;
  };
  fileSystems."/z/persist" = {
    device = "/dev/mapper/${luksDevice}";
    fsType = "btrfs";
    options = mkSubvol "persist" "compress=zstd:3";
    neededForBoot = true;
  };
  fileSystems."/z/home" = {
    device = "/dev/mapper/${luksDevice}";
    fsType = "btrfs";
    options = mkSubvol "home" "compress=zstd:3";
    neededForBoot = true;
  };
  fileSystems."/z/cache" = {
    device = "/dev/mapper/${luksDevice}";
    fsType = "btrfs";
    options = mkSubvol "cache" "compress-force=zstd:5";
    neededForBoot = true;
  };

  # wipe root partition on boot
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir -p /mnt
    mount -o subvol=/ /dev/mapper/${luksDevice} /mnt

    # delete old root
    if [ -e /mnt/root ]; then
      btrfs subvolume delete -R /mnt/root
    fi

    # create a new root
    btrfs subvolume create /mnt/root
    umount /mnt
  '';

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
