{
  host,
  ...
}:
{
  zramSwap.enable = true;

  sops.groups.system.user-key = {
    value = "op://Private/mimvtzkpohm5bbbm5d6kpwp4aa/private key?ssh-format=openssh";
    owner = host.username;
  };
}
