{
  host,
  xelib,
  ...
}:
{
  imports = [
    ./prowlarr.nix
    ./sonarr.nix
  ];

  # mount the shared backup directory
  systemd.services = xelib.mkRcloneMount {
    config = "/home/${host.username}/.config/rclone/rclone.conf";
    name = "servarr-backups";
    remote = "pcloud:/Misc/Backups/Servarr";
    mountPoint = "/mnt/servarr_backups";
    extraArgs = [
      "--allow-other"
      "--dir-perms=0777"
      "--file-perms=0666"
    ];
  };
}
