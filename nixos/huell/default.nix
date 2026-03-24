{
  config,
  host,
  ...
}:
{
  zramSwap.enable = true;

  sops.secrets.user_key = {
    sopsFile = config.sops.opSecrets.user_key.fullPath;
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/mimvtzkpohm5bbbm5d6kpwp4aa/private key?ssh-format=openssh";
}
