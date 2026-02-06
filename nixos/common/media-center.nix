# shared options for media center related applications
{
  host,
  lib,
  xelib,
  ...
}:
let
  # shared options for rclone
  config = "/home/${host.username}/.config/rclone/rclone.conf";
  extraArgs = [
    # allow access
    "--allow-other"
    "--dir-perms=0777"
    "--file-perms=0666"
    # performance
    "--dir-cache-time=168h"
    "--poll-interval=5m"
    "--buffer-size=128M"
  ];
in
{
  systemd.services = lib.mkMerge [
    # TV Shows
    (xelib.mkRcloneMount {
      inherit config extraArgs;
      name = "tv";
      remote = "pcloud:/Media/TVShows";
      mountPoint = "/mnt/tv";
    })
    # Movies
    (xelib.mkRcloneMount {
      inherit config extraArgs;
      name = "movies";
      remote = "pcloud:/Media/Movies";
      mountPoint = "/mnt/movies";
    })
  ];
}
