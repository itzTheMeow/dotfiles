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
    ../common/headless-vps.nix
    ../common/media-center.nix

    ../programs/rustic.nix

    ../services/beszel/agent.nix
    ../services/nginx
    ../services/rustic
    ../services/ssh
    ../services/tailscale

    ../services/step-ca
  ];

  sops.secrets.user_key = {
    sopsFile = "${self}/${config.sops.opSecrets.user_key.path}";
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/vqhxrcxgookq6e6vu3etmjev2e/private key?ssh-format=openssh";
}
