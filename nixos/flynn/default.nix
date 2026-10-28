{
  host,
  lib,
  pkgs,
  ...
}:
{
  # bootloader
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
      default = 2;
    };
    timeout = 1;
    efi.canTouchEfiVariables = true;
  };

  # custom hostname for this device
  networking.hostName = lib.mkForce "meow-pc";

  environment.sessionVariables = {
    # this is for node-canvas...
    LD_LIBRARY_PATH = with pkgs; [
      (lib.makeLibraryPath [
        libuuid
      ])
    ];
    GSK_RENDERER = "cairo"; # force software rendering for GTK4 (fixes graphical issues)
    PLASMA_USE_QT_SCALING = "1";
  };

  # enable docker
  virtualisation.docker.enable = true;

  # throwaway Debian VM for AI coding-agent tests
  services.ai-test-vm.enable = true;

  environment.systemPackages = with pkgs; [
    (teams-for-linux.overrideAttrs (old: {
      # check fails on github CI, ts will be removed soon anyway
      doInstallCheck = false;
    }))
  ];

  systemd.tmpfiles.rules = [
    "L+ /home/pcloud - - - - /home/${host.username}/pCloudDrive"
  ];

  sops.groups.system.user-key = {
    value = "op://Private/3qhsyka4n4ivngmjow5tysb3da/private key?ssh-format=openssh";
    owner = host.username;
  };
}
