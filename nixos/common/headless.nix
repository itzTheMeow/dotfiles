{ host, pkgs, ... }:
{
  systemd.services."home-manager-${host.username}" = {
    wantedBy = pkgs.lib.mkForce [ ];

    serviceConfig = {
      EnvironmentFile = "-/run/1password-session";
    };
  };
}
