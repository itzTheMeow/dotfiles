# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  pkgs,
  username,
  xelib,
  ...
}:
{
  imports = [
    ./common
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  services.openssh.enable = true;
  services.tailscale.enable = true;
}
