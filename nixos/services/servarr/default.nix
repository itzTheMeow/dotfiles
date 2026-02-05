{ username, ... }:
{
  imports = [
    ./prowlarr.nix
  ];

  fileSystems."/mnt/servarr_backups" = {
    device = "pcloud:/Misc/Backups/Servarr/";
    fsType = "rclone";
    options = [
      "nofail"
      "allow_other"
      "config=/home/${username}/rclone/rclone.conf"
    ];
  };
}
