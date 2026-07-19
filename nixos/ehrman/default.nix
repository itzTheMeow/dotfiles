{
  host,
  ...
}:
{
  nginx.enable = true;

  sops.groups.system.user-key = {
    value = "op://Private/zfo56rnxe3rtoigohaemc7lx6i/private key?ssh-format=openssh";
    owner = host.username;
  };
}
