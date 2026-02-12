profileName:
{
  host,
  pkgs,
  xelib,
  ...
}:
{
  # rustic backup scheduler
  systemd.services.rustic-backup =
    let
      home = /home/${host.username};
      env = [
        # define these so rustic will work properly off of the user config
        "PATH=${home}/.nix-profile/bin:$PATH"
        "HOME=${home}"
        "RCLONE_CONFIG=${home}/.config/rclone/rclone.conf"
        "NTFY_CONFIG=${home}/.config/ntfy/client.yml"
      ];
    in
    {
      description = "Rustic backup";
      environment = xelib.globals.environment;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.zsh}/bin/zsh -c 'export ${builtins.concatStringsSep " " env} && ${pkgs.rustic}/bin/rustic -P ${profileName} backup'";
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
