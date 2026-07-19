{
  host,
  ...
}:
{
  nginx.enable = true;

  sops.groups.system.user-key = {
    value = "op://Private/vqhxrcxgookq6e6vu3etmjev2e/private key?ssh-format=openssh";
    owner = host.username;
  };
}
