{
  pkgs,
  xelpkgs,
  ...
}:
{
  systemd.user.services.download-organizer = {
    Unit = {
      Description = "Download Organizer Service";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Path = [
        pkgs.rclone
        xelpkgs.download-organizer
      ];
      ExecStart = pkgs.writeShellScript "download-organizer-wrapper" ''
        set -e

        # create a temporary mount point
        MOUNT_DIR=$(mktemp -d)

        # function to cleanup mount
        cleanup() {
            echo "Unmounting rclone mount..."
            fusermount -u "$MOUNT_DIR"
            rmdir "$MOUNT_DIR"
            echo "Cleanup done."
        }

        # trap exit to ensure cleanup
        trap cleanup EXIT

        echo "Mounting rclone remote..."
        rclone mount "pcloud:/Downloads" "$MOUNT_DIR" --daemon
        if [ $? -ne 0 ]; then
            echo "Failed to mount rclone remote."
            exit 1
        fi

        # wait for mount to become available
        sleep 2

        echo "Running script on mounted folder..."
        download-organizer "$MOUNT_DIR"
      '';
    };
  };

  systemd.user.timers.download-organizer = {
    Unit = {
      Description = "Download Organizer Timer";
      Requires = [ "download-organizer.service" ];
    };
    Timer = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
