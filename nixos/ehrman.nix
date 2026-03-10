{
  config,
  host,
  hostname,
  pkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix
    ./common/headless-vps.nix

    ./programs/rustic.nix

    ./services/beszel/agent.nix
    ./services/nginx
    (import ./services/rustic hostname)
    ./services/ssh
    ./services/tailscale

    # specific to this host
    ./services/headscale
    ./services/tailscale/mullvad-exit-nodes.nix
  ];

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
    "op://Private/zfo56rnxe3rtoigohaemc7lx6i/private key?ssh-format=openssh";
}
