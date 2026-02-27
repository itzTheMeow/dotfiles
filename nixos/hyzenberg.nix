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
    ./common/media-center.nix

    ./services/beszel/agent.nix
    ./services/nginx
    (import ./services/rustic "hyzen2")
    ./services/ssh
    ./services/tailscale

    # specific to this host
    ./services/beszel
    ./services/nzbget
    ./services/servarr
    ./services/step-ca
    ./services/homepage
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;

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
    "op://Private/vqhxrcxgookq6e6vu3etmjev2e/private key?ssh-format=openssh";
}
