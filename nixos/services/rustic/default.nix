profileName:
{
  host,
  pkgs,
  xelib,
  ...
}:
{
  # rustic backup scheduler
  systemd.services.rustic-backup = {
    description = "Rustic backup";
    environment = xelib.globals.environment;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.zsh}/bin/zsh -c 'export PATH=/home/${host.username}/.nix-profile/bin:$PATH && HOME=/home/${host.username} RCLONE_CONFIG=/home/${host.username}/.config/rclone/rclone.conf ${pkgs.rustic}/bin/rustic -P ${profileName} backup'";
    };
  };
  systemd.timers.rustic-backup = {
    description = "Rustic backup timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = host.backupFrequency;
      Persistent = true;
    };
  };
}
