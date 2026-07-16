{
  config,
  host,
  hostname,
  inputs,
  lib,
  pkgs-unstable,
  pkgs,
  self,
  xelib,
  ...
}:
let
  commonFiles = builtins.readDir ./_common;
in
{
  system.stateVersion = "25.11";

  home-manager.importAll = [
    ./common.hm.nix
    # import local config
    ../local/home-manager.nix
  ];
  home-manager.importUser = [ ./common.user.hm.nix ];

  imports =
    # import all .nix files in common
    map (name: ./_common + "/${name}") (
      builtins.filter (
        name:
        # all nix files
        commonFiles.${name} == "regular"
        && builtins.match ".*\\.nix" name != null
        # ignore home-manager modules
        && builtins.match ".*\\.hm\\.nix" name == null
      ) (builtins.attrNames commonFiles)
    )
    # import type configs
    ++ map (name: ./_types + "/${name}") host.type;

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

  # link current nix config to /run/current-system/src
  system.systemBuilderCommands = ''
    ln -s ${self.outPath} $out/src
  '';

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

  # configure ACME for cert management
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "ca@xela.codes";
      webroot = "/var/lib/acme/acme-challenge";
      group = "nginx";
    };
  };

  users = {
    # enable declarative users / passwords
    mutableUsers = false;
    users = {
      root = {
        # disable root login
        hashedPassword = null;
        # enable user sessions since we cant log in
        linger = true;
      };

      # configure default user
      ${host.username} = {
        isNormalUser = true;
        description = if (host ? fullname) then host.fullname else xelib.toTitleCase host.username;
        linger = true; # start user sessions on machine boot
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        hashedPasswordFile = config.sops.secrets.password.path;
      };
    };
  };
  # default user password via sops
  sops.secrets.password = {
    sopsFile = config.sops.opSecrets.password.fullPath;
    key = "password";
    neededForUsers = true;
  };
  sops.opSecrets.password.keys.password = "op://Private/${hostname} User Password/credential";

  # clear /tmp on boot
  boot.tmp.cleanOnBoot = true;

  # enable zram
  zramSwap.enable = true;

  # networking settings
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
  }
  # manually configure network for supported hosts
  // lib.optionalAttrs (host ? net) {
    nameservers = host.net.nameservers ++ [
      "1.1.1.1"
      "9.9.9.9"
    ];
    defaultGateway = {
      address = host.net.gateway;
      inherit (host.net) interface;
    };
    defaultGateway6 = {
      address = host.net.gateway6;
      inherit (host.net) interface;
    };
    interfaces.${host.net.interface} = {
      ipv4.addresses = [
        {
          address = xelib.dns.addr.${hostname};
          prefixLength = 22;
        }
      ];
      ipv6.addresses = [
        {
          address = xelib.dns.addr6.${hostname};
          prefixLength = 64;
        }
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    # system-level utilities
    ## basic deps
    curl
    git
    jq
    killport
    openssl
    wev
    wget

    ## build tools
    check
    cloc
    gcc
    gnumake
    just
    pkg-config

    ## nix-related
    cachix
    home-manager
    nix-diff
    nixpkgs-review

    ## editors
    nano

    ## system
    dnsutils
    e2fsprogs
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
    DOTFILES = xelib.location;
    HOSTNAME = hostname;
    NIXPKGS_ALLOW_UNFREE = "1";
  };
  # exclude default KDE apps from plasma
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa
  ];

  # allow other flag for fuse mounts
  programs.fuse.userAllowOther = true;

  # default ssh settings
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # install 1password cli
  programs._1password.enable = true;
  # persist CLI config
  persist.ed.home.userFiles = [ ".config/op/config" ];

  # sops doesnt need rsa keys
  sops.gnupg.sshKeyPaths = [ ];

  # trust nixos and cachix caches
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "https://xelacodes.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "xelacodes.cachix.org-1:mlXOAvMV//6WvlZAv0xu8fBflpDZTOo9n4mU9W7XxyU="
    ];
  };

  # catppuccin settings
  catppuccin = {
    enable = true;
    autoEnable = false;
    inherit (xelib.globals.catppuccin) accent flavor;
  };

  persist.ed.persist = {
    directories = [
      {
        var = {
          lib = [
            "nixos" # nix state info
            "systemd/coredump"
          ];
          log = [ ];
        };
      }
    ];
    files = [
      # keep trust settings for rebuilds
      "/root/.local/share/nix/trusted-settings.json"
      {
        etc = [
          # keep ssh host keys
          {
            ssh = [
              "ssh_host_ed25519_key.pub"
              "ssh_host_ed25519_key"
              "ssh_host_rsa_key.pub"
              "ssh_host_rsa_key"
            ];
          }
          # and machine ID
          "machine-id"
        ];
      }
    ];
  };
}
