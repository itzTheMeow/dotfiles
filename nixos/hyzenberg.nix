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

    ./services/ssh
    ./services/tailscale
    ./services/step-ca

    # specific to this host
    ./services/nzbget
    ./services/servarr
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Enable and configure Nginx
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "1g";
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
