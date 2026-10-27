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

  # NOTE: disk migration (ext4 -> LUKS2 + btrfs):
  #   - vda1: LUKS2 container (partlabel "root", partuuid 130b4cab-c05d-40a1-87a2-2bc63b1a33d3)
  #     -> btrfs with flynn-style subvol naming ("root" for /, "nix" for /nix),
  #     so impermanence can be enabled later by setting
  #     persist.settings.device = "/dev/mapper/cryptroot" (the persist module
  #     then owns fileSystems for /, /nix, and additional /z/<name> entries).
  #     Remove the fileSystems."/" and fileSystems."/nix" entries here once
  #     the persist module takes them over. The "root" subvol currently holds
  #     everything except the nix store.

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
      "${utils.escapeSystemdPath "/dev/disk/by-partuuid/F9E6C80B-DF4F-4DAD-BB9D-B8B083D920AC"}.device"
    ];
    requires = [
      "${utils.escapeSystemdPath "/dev/disk/by-partuuid/F9E6C80B-DF4F-4DAD-BB9D-B8B083D920AC"}.device"
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /run/luks-esp
      mount -t vfat /dev/disk/by-partuuid/F9E6C80B-DF4F-4DAD-BB9D-B8B083D920AC /run/luks-esp
    '';
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/98ddbc3b-a238-4897-97c6-21e06f3d2f44";
    fsType = "btrfs";
    options = [
      "subvol=root"
      "compress=zstd:1"
      "noatime"
    ];
  };
  # mirror the persist module's mkBtrfsMount "nix" 5 true, so the handover is seamless
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/98ddbc3b-a238-4897-97c6-21e06f3d2f44";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress-force=zstd:5"
      "noatime"
    ];
    neededForBoot = true;
  };
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
