{
  pkgs,
  xelpkgs,
  ...
}:
{
  systemd.user.services.download-organizer = {
    unitConfig = {
      Description = "Download Organizer Service";
    };
    path = [
      pkgs.fuse3
      pkgs.rclone
      xelpkgs.download-organizer
    ];
    serviceConfig = {
      Type = "oneshot";
      PrivateTmp = "no";

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
        rclone mount "pcloud:/Downloads" "$MOUNT_DIR" &
        RCLONE_PID=$!

        MOUNTED=false
        for i in {1..10}; do
            if mountpoint -q "$MOUNT_DIR"; then
                MOUNTED=true
                break
            fi
            sleep 1
        done

        if [ "$MOUNTED" = false ]; then
            echo "Error: Rclone failed to mount within 10 seconds."
            exit 1
        fi

        echo "Running script on mounted folder..."
        download-organizer "$MOUNT_DIR"

        kill $RCLONE_PID
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
