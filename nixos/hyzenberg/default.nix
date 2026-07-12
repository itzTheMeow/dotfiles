{
  config,
  host,
  hostname,
  xelib,
  ...
}:
{
  nginx.enable = true;

  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "ens3";
  };
  networking.interfaces.ens3.ipv6.addresses = [
    {
      address = xelib.dns.addr6.${hostname};
      prefixLength = 64;
    }
  ];

  sops.secrets.user_key = {
    sopsFile = config.sops.opSecrets.user_key.fullPath;
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/vqhxrcxgookq6e6vu3etmjev2e/private key?ssh-format=openssh";
}
