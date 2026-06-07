{ host, ... }:
{
  environment.persistence."/z/persist" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/log"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh_host_ed25519_key.pub"
      "/etc/ssh_host_ed25519_key"
      "/etc/ssh_host_rsa_key.pub"
      "/etc/ssh_host_rsa_key"
    ];
  };

  #TODO: temporary
  environment.persistence."/z/home" = {
    hideMounts = true;
    users.${host.username} = {
      directories = [
        "."
      ];
    };
  };

  environment.persistence."/z/cache" = {
    hideMounts = true;
    allowTrash = true;
    users.${host.username} = {
      directories = [
        ".local/share/Trash"
      ];
    };
  };

  /*
    # btrfs tools available in the initrd stage
    boot.initrd.supportedFilesystems = [ "btrfs" ];

    # wipe root partition
    boot.initrd.postDeviceCommands = lib.mkAfter ''
      mkdir -p /mnt
      mount -o subvol=/ /dev/mapper/cryptroot /mnt

      if [ -e /mnt/root ]; then
          btrfs subvolume delete /mnt/root
      fi

      btrfs subvolume create /mnt/root
      umount /mnt
    '';

    # hide /z
    system.activationScripts.hidePersistentMounts = ''
      echo -e "z" > /.hidden
    '';

    # weekly background TRIM
    services.fstrim.enable = true;
  */
}
