# shared options for media center related applications
{
  host,
  ...
}:
let
  # shared options for rclone
  options = {
    # allow access
    allow-other = true;
    dir-perms = "0777";
    file-perms = "0666";
    # performance
    dir-cache-time = "168h";
    poll-interval = "3m";
    buffer-size = "128M";
  };
in
{
  home-manager.users.${host.username}.programs.rclone.remotes.pcloud.mounts = {
    "/Media/TVShows" = {
      enabled = true;
      mountPoint = "/mnt/tv";
      inherit options;
    };
    "/Media/Movies" = {
      enabled = true;
      mountPoint = "/mnt/movies";
      inherit options;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/tv 0755 ${host.username} users -"
    "d /mnt/movies 0755 ${host.username} users -"
  ];
}
