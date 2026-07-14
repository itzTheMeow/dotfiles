{
  config,
  host,
  lib,
  pkgs,
  xelib,
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

  environment.sessionVariables = xelib.globals.environment // {
    # this is for node-canvas...
    LD_LIBRARY_PATH = with pkgs; [
      (lib.makeLibraryPath [
        libuuid
      ])
    ];
    # set the 1password ssh auth socket
    SSH_AUTH_SOCK = "/home/${host.username}/.1password/agent.sock";
  };

  # enable docker
  virtualisation.docker.enable = true;

  # development
  programs.vscode = {
    enable = true;
    package = pkgs.vscode-fhs;
  };

  systemd.tmpfiles.rules = [
    "L+ /home/pcloud - - - - /home/${host.username}/pCloudDrive"
  ];

  sops.secrets.user_key = {
    sopsFile = config.sops.opSecrets.user_key.fullPath;
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/3qhsyka4n4ivngmjow5tysb3da/private key?ssh-format=openssh";
}
