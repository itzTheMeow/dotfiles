{ hostname, pkgs, ... }:
{
  system.stateVersion = "25.11";

  imports = [
    # import hardware config for host
    ../${hostname}-hardware.nix
    # import local config
    ../../local/nixos.nix
  ];

  # base nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  # garbage collection for derivations
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  boot.loader.systemd-boot.configurationLimit = 3;

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # timezone should be synced
  time.timeZone = "America/New_York";

  # english language
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # passwordless sudo
  security.sudo.wheelNeedsPassword = false;
  # disable root login password
  users.users.root.hashedPassword = null;

  # clear /tmp on boot
  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    # system-level utilities
    gcc
    gnumake
    home-manager
    nano
    pandoc
    pciutils
    texliveSmall
  ];

  # allow other flag for fuse mounts
  programs.fuse.userAllowOther = true;

  # enable zsh
  programs.zsh.enable = true;

  # default ssh settings
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
}
