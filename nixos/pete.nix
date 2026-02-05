# most of this is from this PR: https://github.com/NixOS/nixpkgs/pull/428353
# and this VM: https://git.allpurposem.at/mat/bigscreen-waydroid-vm/src/commit/d5a30a4cc69065a84c4ae16b59b54d8b06174347/configuration.nix
{
  host,
  pkgs,
  xelib,
  xelpkgs,
  ...
}:
{
  imports = [
    ./common
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.${host.username} = {
    isNormalUser = true;
    description = xelib.toTitleCase host.username;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    initialPassword = "test"; # temp:vm
  };

  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm = {
      enable = true;
      theme = "breeze";
      wayland.enable = true;
      enableHidpi = true;
      settings = {
        Autologin = {
          Session = "plasma-bigscreen-wayland";
          User = host.username;
        };
      };
    };
    displayManager.sessionPackages = [
      xelpkgs.plasma-bigscreen
    ];
  };

  xdg.portal.configPackages = [ xelpkgs.plasma-bigscreen ];
  environment.systemPackages = [
    xelpkgs.plasma-bigscreen
  ];
}
