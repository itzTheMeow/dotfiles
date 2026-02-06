{ host, pkgs, ... }:
{
  systemd.services."home-manager-${host.username}" = {
    # only run if 1password session file exists (prevents running on boot)
    unitConfig.ConditionPathExists = "/run/1password-session";

    serviceConfig = {
      # include saved 1password session in environment
      EnvironmentFile = "-/run/1password-session";
    };
  };
}
