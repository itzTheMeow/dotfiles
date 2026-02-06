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
    ./services/step-ca

    # specific to this host
    ./services/servarr
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  # Enable and configure Nginx
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  users.users.${host.username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}
