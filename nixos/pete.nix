{
  config,
  host,
  xelpkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/desktop.nix
    ./common/desktop-kde.nix

    ./gaming

    ./programs/rustic.nix

    ./services/ssh
    ./services/tailscale
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      memtest86.enable = true;
    };
    timeout = 3;
    efi.canTouchEfiVariables = true;
  };

  # most of this is from this PR: https://github.com/NixOS/nixpkgs/pull/428353
  # and this VM: https://git.allpurposem.at/mat/bigscreen-waydroid-vm/src/commit/d5a30a4cc69065a84c4ae16b59b54d8b06174347/configuration.nix
  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm = {
      enable = true;
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

  sops.secrets.user_key = {
    sopsFile = ../${config.sops.opSecrets.user_key.path};
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/wd7y5xz4qgp5loohnmc4wrj3t4/private key?ssh-format=openssh";
}
