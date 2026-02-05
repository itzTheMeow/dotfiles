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

  # ssh
  services.openssh = {
    enable = true;
    listenAddresses = [
      {
        addr = xelib.hosts.hyzenberg.ip;
        port = xelib.hosts.hyzenberg.ports.ssh;
      }
    ];
  };

  systemd.services.sshd.after = [ "tailscale-online.service" ];
}
