{
  config,
  host,
  inputs,
  ...
}:
{
  #TODO:nixos-26.05 replace the module with the one from unstable (temp)
  disabledModules = [ "services/networking/anubis.nix" ];
  imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/services/networking/anubis.nix" ];

  nginx.enable = true;

  sops.secrets.user_key = {
    sopsFile = config.sops.opSecrets.user_key.fullPath;
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/vqhxrcxgookq6e6vu3etmjev2e/private key?ssh-format=openssh";
}
