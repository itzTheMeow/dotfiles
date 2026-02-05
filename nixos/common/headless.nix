{ host, ... }:
{
  # load 1password variables from saved session
  systemd.services."home-manager-${host.username}" = {
    serviceConfig.EnvironmentFile = "-/run/1password-session";
  };
}
