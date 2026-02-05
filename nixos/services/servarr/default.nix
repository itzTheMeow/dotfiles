{
  host,
  xelib,
  ...
}:
{
  imports = [
    ./prowlarr.nix
  ];

  systemd.services = xelib.mkRcloneMount {
    config = "/home/${host.username}/.config/rclone/rclone.conf";
    name = "servarr-backups";
    remote = "pcloud:/Misc/Backups/Servarr";
    mountPoint = "/mnt/servarr_backups";
  };
}
