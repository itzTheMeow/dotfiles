{
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

    ./services/nginx
    ./services/ssh
    ./services/tailscale
    ./services/step-ca

    # specific to this host
    ./services/nzbget
    ./services/servarr
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
}
