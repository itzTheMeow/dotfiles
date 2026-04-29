{
  host,
  pkgs,
  xelpkgs,
  ...
}:
let
  mountPoint = "/home/${host.username}/.cache/pcloud-download-organizer";
  unit = "rclone-mount:.Downloads@pcloud.service";
in
{
  home-manager.users.${host.username}.programs.rclone.remotes.pcloud.mounts."/Downloads" = {
    enable = true;
    autoMount = false;
    inherit mountPoint;
  };

  systemd.user.services.download-organizer = {
    unitConfig = {
      Description = "Download Organizer Service";
      After = [ unit ];
      Requires = [ unit ];
    };
    serviceConfig = {
      Type = "oneshot";
      # stop the unit when finished
      ExecStartPost = "${pkgs.systemd}/bin/systemctl --user stop ${unit}";
      ExecStart = ''
        ${xelpkgs.download-organizer}/bin/download-organizer "${mountPoint}"
      '';
    };
  };

  systemd.user.timers.download-organizer = {
    unitConfig = {
      Description = "Download Organizer Timer";
      Requires = [ "download-organizer.service" ];
    };
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };
}
