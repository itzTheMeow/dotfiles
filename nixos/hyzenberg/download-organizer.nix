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
  home-manager.users.${host.username} = {
    programs.rclone.remotes.pcloud.mounts."/Downloads" = {
      enable = true;
      autoMount = false;
      inherit mountPoint;
    };
  };
  systemd.user.services.${unit}.serviceConfig.SuccessExitStatus = "143";

  systemd.user.services.download-organizer = {
    unitConfig = {
      Description = "Download Organizer Service";
      After = [ unit ];
    };
    serviceConfig = {
      Type = "oneshot";
      # start unit before running
      ExecStartPre = "${pkgs.systemd}/bin/systemctl --user start ${unit}";
      ExecStart = ''
        ${xelpkgs.download-organizer}/bin/download-organizer "${mountPoint}"
      '';
      # stop the unit when finished
      ExecStopPost = "${pkgs.systemd}/bin/systemctl --user stop ${unit}";
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
