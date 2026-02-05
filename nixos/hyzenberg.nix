{
  pkgs,
  username,
  xelib,
  ...
}:
{
  imports = [
    ./common
    ./services/servarr
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  networking.hostName = "hyzenberg";

  networking.networkmanager.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = xelib.toTitleCase username;
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
        addr = xelib.hosts.hyzenberg;
        port = xelib.ports.ssh-hyzenberg;
      }
    ];
  };
  systemd.services.sshd = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };

  services.tailscale.enable = true;
}
