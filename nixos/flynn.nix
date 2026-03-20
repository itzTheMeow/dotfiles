{
  config,
  host,
  lib,
  pkgs-unstable,
  pkgs,
  xelib,
  xelpkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/desktop.nix
    ./common/desktop-kde.nix
    ./common/desktop-workstation.nix

    ./gaming

    ./services/beszel/agent.nix
    ./services/rustic
    ./services/ssh
    ./services/tailscale

    ./programs/discord-rich-presence-plex.nix
    ./programs/immich.nix
    ./programs/rustic.nix
  ];

  # Bootloader.
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

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  environment.sessionVariables = xelib.globals.environment // {
    # this is for node-canvas...
    LD_LIBRARY_PATH =
      with pkgs;
      lib.makeLibraryPath [
        libuuid
      ];
    # set the 1password ssh auth socket
    SSH_AUTH_SOCK = "/home/${host.username}/.1password/agent.sock";
  };

  # browsing
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition;
  };

  # enable 1Password browser integration
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      firefox-devedition
    '';
    mode = "0755";
  };

  programs.chromium = {
    enable = true;
    extensions = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "cndibmoanboadcifjkjbdpjgfedanolh" # BetterCanvas
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "cimiefiiaegbelhefglklhhakcgmhkai" # Plasma Integration
      "clngdbkpkpeebahjckkjfobafhncgmne" # Stylus
      "dhdgffkkebhmkfjojejmpbldmpobfkfo" # Tampermonkey
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
    ];
  };

  # development
  programs.vscode = {
    enable = true;
    package = pkgs.vscode-fhs;
  };

  environment.systemPackages = with pkgs; [
    # system-level apps
    chromium
    libreoffice
    vlc
  ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    package = pkgs-unstable._1password-gui;
    polkitPolicyOwners = [ host.username ];
  };

  systemd.tmpfiles.rules = [
    "L+ /home/pcloud - - - - /home/${host.username}/pCloudDrive"
  ];

  sops.secrets.user_key = {
    sopsFile = ../${config.sops.opSecrets.user_key.path};
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/3qhsyka4n4ivngmjow5tysb3da/private key?ssh-format=openssh";
}
