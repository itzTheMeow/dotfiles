{
  host,
  hostname,
  inputs,
  pkgs,
  ...
}:
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
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

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

  systemd.services."home-manager-${host.username}" = {
    # only run if 1password session file exists (prevents running on boot)
    unitConfig.ConditionPathExists = "/run/1password-session";

    serviceConfig = {
      # include saved 1password session in environment
      EnvironmentFile = "-/run/1password-session";
    };
  };

  # passwordless sudo
  security.sudo.wheelNeedsPassword = false;

  # trust our custom CA
  security.pki.certificateFiles = [
    ../services/step-ca/root_ca.crt
  ];
  # configure ACME for cert management
  security.acme = {
    acceptTerms = true;
    defaults.email = "ca@xela.codes";
  };

  # disable root login password
  users.users.root.hashedPassword = null;

  # clear /tmp on boot
  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    # system-level utilities
    ## build tools
    check
    gcc
    gnumake
    pkg-config

    ## nix-related
    home-manager

    ## editors
    nano

    ## system
    pciutils

    ## pandoc
    pandoc
    texliveSmall

    ## networking
    dig
    net-tools
    tcpdump

    kitty # needed so ssh will work from kitty
    rclone # used by some core services
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
