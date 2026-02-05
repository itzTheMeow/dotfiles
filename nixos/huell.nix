{ host, pkgs, ... }:
{
  imports = [
    ./common
    ./common/headless.nix

    ./services/ssh
  ];

  zramSwap.enable = true;
  networking.hostName = "meow";

  users.users.${host.username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAp+ia8qqQVHmHr8fzALeNBse6kBaKGXeWznDN0lAmYE"
  ];
}
