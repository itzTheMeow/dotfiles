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
    umask = "002";
    gid = "mediacenter";
    # performance
    dir-cache-time = "168h";
    poll-interval = "3m";
    buffer-size = "128M";
  };
in
{
  users.groups.mediacenter = { };
  users.users.${host.username}.extraGroups = [ "mediacenter" ];

  home-manager.users.${host.username}.programs.rclone.remotes.pcloud.mounts = {
    "/Media/TVShows" = {
      enable = true;
      mountPoint = "/mnt/tv";
      inherit options;
    };
    "/Media/Movies" = {
      enable = true;
      mountPoint = "/mnt/movies";
      inherit options;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/tv 0775 ${host.username} mediacenter -"
    "d /mnt/movies 0775 ${host.username} mediacenter -"
  ];
}
