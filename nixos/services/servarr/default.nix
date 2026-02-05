{ username, ... }:
{
  imports = [
    ./prowlarr.nix
  ];

  fileSystems."/mnt/servarr_backups" = {
    device = "pcloud:/Misc/Backups/Servarr/";
    fsType = "rclone";
    options = [
      "nodev"
      "nofail"
      "allow_other"
      "args2env"
      "config=/home/${username}/.config/rclone/rclone.conf"
    ];
  };
}
