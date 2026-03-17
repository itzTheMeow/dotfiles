{
  host,
  hostname,
  inputs,
  pkgs,
  pkgs-unstable,
  xelib,
  ...
}:
{
  system.stateVersion = "25.11";

  imports = [
    # import hardware config for host
    ../${hostname}-hardware.nix
    # import local config
    ../../local/nixos.nix

    ../programs/ntfy.nix
  ];

  # base nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [ "@wheel" ];
  };
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.channel.enable = false;

  # garbage collection for derivations
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  boot.loader.systemd-boot.configurationLimit = 5;

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # VM settings
  virtualisation.vmVariant.virtualisation = {
    memorySize = 6 * 1024;
    cores = 5;
  };

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

  # trust our custom CA
  security.pki.certificateFiles = [
    ../services/step-ca/root_ca.crt
  ];
  # configure ACME for cert management
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "ca@xela.codes";
      webroot = "/var/lib/acme/acme-challenge";
      group = "nginx";
    };
  };

  # disable root login password
  users.users.root.hashedPassword = null;

  # configure default user
  users.users.${host.username} = {
    isNormalUser = true;
    description = if (host ? fullname) then host.fullname else xelib.toTitleCase host.username;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # clear /tmp on boot
  boot.tmp.cleanOnBoot = true;

  # networking settings
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # system-level utilities
    ## basic deps
    curl
    git
    jq
    killport
    wget

    ## build tools
    check
    cloc
    gcc
    gnumake
    pkg-config

    ## nix-related
    cachix
    home-manager
    nixpkgs-review

    ## editors
    nano

    ## system
    dnsutils
    pciutils
    usbutils

    ## file management
    ncdu
    renameutils
    tree

    ## ffmpeg/pandoc/yt-dlp
    ffmpeg-full
    pandoc
    texliveSmall
    pkgs-unstable.yt-dlp

    ## networking
    dig
    net-tools
    tcpdump

    ## archiving
    p7zip
    unzip

    kitty # needed so ssh will work from kitty
    rclone # used by some core services
    screen
  ];
  environment.variables = {
    NIXPKGS_ALLOW_UNFREE = "1";
  };
  # exclude default KDE apps from plasma
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa
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
