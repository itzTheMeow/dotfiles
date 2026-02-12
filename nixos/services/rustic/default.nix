profileName:
{
  host,
  pkgs,
  xelib,
  ...
}:
{
  # rustic backup scheduler
  systemd.user.services.rustic-backup = {
    description = "Rustic backup";
    environment = xelib.globals.environment;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.zsh}/bin/zsh -c 'export PATH=/home/${host.username}/.nix-profile/bin:$PATH && ${pkgs.rustic}/bin/rustic -P ${profileName} backup'";
    };
  };
  systemd.user.timers.rustic-backup = {
    description = "Rustic backup timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = host.backupFrequency;
      Persistent = true;
    };
  };
}
