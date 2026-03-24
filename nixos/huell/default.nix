{
  config,
  host,
  self,
  ...
}:
{
  imports = [
    ../common
    ../common/headless.nix

    ../services/ssh
    ../services/tailscale
  ];

  zramSwap.enable = true;

  sops.secrets.user_key = {
    sopsFile = "${self}/${config.sops.opSecrets.user_key.path}";
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/mimvtzkpohm5bbbm5d6kpwp4aa/private key?ssh-format=openssh";
}
