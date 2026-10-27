{
  lib,
  modulesPath,
  utils,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci" # Standard for KVM communication
    "virtio_blk" # High-performance block storage driver
    "virtio_scsi" # Alternative driver; often faster for SSDs
    "virtio_net" # Essential for Gbit+ networking
    "virtio_balloon" # Allows the host to manage RAM efficiently
    "ahci" # Compatibility driver for disk controllers

    "ata_piix"
    "uhci_hcd"
    "sr_mod"

    # the ESP itself gets mounted in the initrd
    "vfat"
    "nls_cp437"
  ];
  # Ensure the AMD-specific KVM optimizations are enabled
  boot.kernelModules = [ "kvm-amd" ];
  boot.kernelParams = [
    "elevator=none" # Disables OS-level disk scheduling (best for NVMe/Virtio)
    "amd_iommu=on" # Enables hardware-level VM isolation
    "amd_pstate=active" # Forces the modern AMD power driver for better boosting
    "nomodeset" # Disable kernel modesetting for better compatibility in VMs
  ];
  powerManagement.cpuFreqGovernor = "performance";

  boot.initrd.supportedFilesystems = [ "vfat" ];
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-partlabel/root";
    keyFile = "/run/luks-esp/luksbootkeyfile";
    allowDiscards = true;
  };
  # Mount the ESP inside the initrd before any LUKS unlock happens.
  boot.initrd.systemd.services.luks-esp = {
    description = "Mount the ESP inside the initrd to expose the LUKS keyfile";
    wantedBy = [ "systemd-cryptsetup@cryptroot.service" ];
    before = [
      "systemd-cryptsetup@cryptroot.service"
      "initrd-switch-root.target"
      "shutdown.target"
    ];
    conflicts = [
      "initrd-switch-root.target"
      "shutdown.target"
    ];
    after = [
      "${utils.escapeSystemdPath "/dev/disk/by-partuuid/f9e6c80b-df4f-4dad-bb9d-b8b083d920ac"}.device"
    ];
    requires = [
      "${utils.escapeSystemdPath "/dev/disk/by-partuuid/f9e6c80b-df4f-4dad-bb9d-b8b083d920ac"}.device"
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /run/luks-esp
      mount -t vfat /dev/disk/by-partuuid/f9e6c80b-df4f-4dad-bb9d-b8b083d920ac /run/luks-esp
    '';
  };

  persist.settings.device = "/dev/mapper/cryptroot";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AC7A-7F39";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
    neededForBoot = true;
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/289ffac7-b242-4b10-a0a5-39d75f745a3f";
      randomEncryption = {
        enable = true;
        # best based on performance
        cipher = "aes-xts-plain64";
        keySize = 512;
      };
    }
  ];

  services.btrfs.autoScrub.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
