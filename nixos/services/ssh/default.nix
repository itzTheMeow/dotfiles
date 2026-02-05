{
  host,
  ...
}:
{
  # ssh
  services.openssh = {
    enable = true;
    listenAddresses = [
      {
        addr = host.ip;
        port = host.ports.ssh;
      }
    ];
  };
  # make sure we wait for tailscale to assign the IP before starting sshd
  systemd.services.sshd.after = [ "tailscale-online.service" ];
}
