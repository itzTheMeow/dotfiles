{
  config,
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
    authorizedKeysFiles = [ config.sops.groupPaths.openssh.authorized_key ];
  };
  # make sure we wait for tailscale to assign the IP before starting sshd
  systemd.services.sshd.after = [ "tailscale-online.service" ];

  sops.groups.openssh.authorized_key = {
    value = host.publicKey;
    mode = "0444";
  };
}
