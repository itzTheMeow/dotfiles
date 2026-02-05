{ pkgs, ... }:
{
  services.tailscale.enable = true;

  # systemd service to wait for ip assignment
  systemd.services.tailscale-wait = {
    description = "Wait for Tailscale IP assignment";
    after = [
      "tailscaled.service"
      "network-online.target"
    ];
    requires = [ "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'until ${pkgs.iproute2}/bin/ip addr show tailscale0 | ${pkgs.gnugrep}/bin/grep -q 100.64.0; do sleep 0.5; done'";
    };
  };
}
