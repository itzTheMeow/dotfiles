{ config, pkgs, xelib, ... }:
let
  # Use Tailscale IP so other devices on the network can access the CA
  tailscaleIP = xelib.hosts.hyzenberg.ip;
  caPort = xelib.services.step-ca.port;
in
{
  # Local ACME CA for .xela and .internal domains
  services.step-ca = {
    enable = true;
    address = tailscaleIP;
    port = caPort;
    intermediatePasswordFile = "/var/lib/step-ca/password.txt";
  };

  # Ensure the step-ca service starts on boot
  systemd.services.step-ca = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
