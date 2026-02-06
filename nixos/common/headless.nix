{ host, pkgs, ... }:
{
  systemd.services."home-manager-${host.username}" = {
    # stops from reactivating on system boot
    wantedBy = pkgs.lib.mkForce [ ];

    serviceConfig = {
      # include saved 1password session in environment
      EnvironmentFile = "-/run/1password-session";
    };
  };
}
