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
    ./services/ssh
    ./services/tailscale

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

  systemd.services."home-manager-${host.username}" = {
    serviceConfig.EnvironmentFile = "-/run/1password-session";
  };
}
