# most of this is from this PR: https://github.com/NixOS/nixpkgs/pull/428353
# and this VM: https://git.allpurposem.at/mat/bigscreen-waydroid-vm/src/commit/d5a30a4cc69065a84c4ae16b59b54d8b06174347/configuration.nix
{
  pkgs,
  username,
  ...
}:
let
  plasma-bigscreen = pkgs.callPackage ../lib/plasma-bigscreen.nix {
    inherit (pkgs.kdePackages)
      kcmutils
      kdeclarative
      ki18n
      kio
      knotifications
      kwayland
      kwindowsystem
      mkKdeDerivation
      qtmultimedia
      plasma-workspace
      bluez-qt
      qtwebengine
      plasma-nano
      plasma-nm
      milou
      kscreen
      kdeconnect-kde
      ;
  };
in
{
  imports = [
    ./common
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "TV";
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
          User = username;
        };
      };
    };
    displayManager.sessionPackages = [
      plasma-bigscreen
    ];
  };

  xdg.portal.configPackages = [ plasma-bigscreen ];
  environment.systemPackages = [
    plasma-bigscreen
  ];

  environment.plasma6.excludePackages = with pkgs; [
    #kdePackages.xwaylandvideobridge
  ];
}
