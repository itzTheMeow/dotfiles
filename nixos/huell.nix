{
  config,
  host,
  pkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix

    ./services/ssh
    ./services/tailscale
  ];

  zramSwap.enable = true;

  users.users.${host.username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  sops.secrets.user_key = {
    sopsFile = ../${config.sops.opSecrets.user_key.path};
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/mimvtzkpohm5bbbm5d6kpwp4aa/private key?ssh-format=openssh";
}
