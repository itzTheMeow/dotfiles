{
  config,
  host,
  ...
}:
{
  imports = [
    ../common
    ../common/headless.nix
    ../common/headless-vps.nix

    ../programs/rustic.nix

    ../services/beszel/agent.nix
    ../services/nginx
    ../services/rustic
    ../services/ssh
    ../services/tailscale
  ];

  sops.secrets.user_key = {
    sopsFile = config.sops.opSecrets.user_key.fullPath;
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/zfo56rnxe3rtoigohaemc7lx6i/private key?ssh-format=openssh";
}
