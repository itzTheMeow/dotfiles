{
  host,
  hostname,
  pkgs,
  xelib,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix

    ./services/ssh
    ./services/tailscale

    # specific to this host
    ./services/servarr
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
}
