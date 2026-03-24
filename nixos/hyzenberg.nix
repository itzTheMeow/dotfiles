{
  config,
  host,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix
    ./common/headless-vps.nix
    ./common/media-center.nix

    ./programs/rustic.nix

    ./services/beszel/agent.nix
    ./services/nginx
    ./services/rustic
    ./services/ssh
    ./services/tailscale

    # specific to this host
    ./services/beszel
    ./services/flixur-demo
    ./services/homepage
    ./services/milfmail.net
    ./services/nsd
    ./services/nzbget
    ./services/servarr
    ./services/step-ca
  ];

  sops.secrets.user_key = {
    sopsFile = config.sops.opSecrets.user_key.fullPath;
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/vqhxrcxgookq6e6vu3etmjev2e/private key?ssh-format=openssh";
}
