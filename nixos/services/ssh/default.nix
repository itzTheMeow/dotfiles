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
    authorizedKeysFiles = [ config.sops.secrets.public_key.path ];
  };
  # make sure we wait for tailscale to assign the IP before starting sshd
  systemd.services.sshd.after = [ "tailscale-online.service" ];

  sops.secrets.public_key = {
    sopsFile = ../../../${config.sops.opSecrets.authorized_keys.path};
    mode = "0444";
  };
  sops.opSecrets.authorized_keys = {
    keys = {
      public_key = host.publicKey;
    };
  };
}
