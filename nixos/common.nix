{
  attics,
  config,
  host,
  hostname,
  impureOverlays,
  inputs,
  lib,
  localDir,
  pkgs,
  self,
  xelib,
  ...
}:
let
  commonFiles = builtins.readDir ./_common;

  # impure nixpkgs overlays, relative to /etc; see the nixpkgs-overlays NIX_PATH entry
  impureOverlaysDir = "nix/nixpkgs-overlays";

  mkSopsWrapper =
    name: dir:
    pkgs.writeShellScriptBin name ''
      set -e
      repo=${lib.escapeShellArg dir}
      prev=""
      for arg in "$@"; do
        case "$prev" in --repo) repo="$arg" ;; esac
        case "$arg" in --repo=*) repo="''${arg#--repo=}" ;; esac
        prev="$arg"
      done
      case "$repo" in ~) repo="$HOME" ;; "~"/*) repo="$HOME/''${repo#\~/}" ;; esac
      ${lib.getExe pkgs.sops-build-secrets} --repo "$repo" --config "$repo/sops.json" "$@"
      if [ -d "$repo/sops" ]; then
        (cd "$repo" && ${lib.getExe pkgs.nix} fmt sops)
      fi
    '';
in
{
  system.stateVersion = "25.11";

  home-manager.importAll = [
    ./common.hm.nix
  ]
  # local config is a committed stub (skip-worktree hides local edits);
  # import unconditionally - pure-eval pathExists cant see untracked files
  ++ lib.optionals (localDir != null) [ (localDir + "/home-manager.nix") ];
  home-manager.importUser = [ ./common.user.hm.nix ];

  # back up files that would be clobbered by home-manager
  home-manager.backupFileExtension = "hm-clobbered";

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
  nix.nixPath = [
    "nixpkgs=${inputs.nixpkgs}"
    "nixpkgs-unstable=${inputs.nixpkgs-unstable}"
  ]
  ++ lib.optionals impureOverlays [ "nixpkgs-overlays=/etc/${impureOverlaysDir}" ];
  nix.channel.enable = false;

  # adds custom overlays to system nixpkgs
  environment.etc = lib.optionalAttrs impureOverlays (
    {
      "${impureOverlaysDir}/zz-unstable.nix".text = ''
        final: prev: {
          unstable = import <nixpkgs-unstable> {
            system = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;
            # required, else nixpkgs re-applies these overlays inside the unstable instance
            # and `unstable.*` recurses forever
            overlays = [ ];
          };
        }
      '';
    }
    // lib.listToAttrs (
      map (name: {
        name = "${impureOverlaysDir}/${name}";
        value.text = ''import "${../overlays}/${name}"'';
      }) (builtins.attrNames (builtins.readDir ../overlays))
    )
  );

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
        hashedPasswordFile = config.sops.groupPaths.system.password;
      };
    };
  };
  # default user password via sops
  sops.groups.system.password = {
    value = "op://Private/${hostname} User Password/credential";
    neededForUsers = true;
  };

  # clear /tmp on boot
  boot.tmp.cleanOnBoot = true;

  # enable zram
  zramSwap = {
    enable = true;
    memoryPercent = 100; # ~100% of RAM as compressed-in-RAM swap (zstd, ~4:1)
  };
  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # keep working set in RAM, spill only cold pages
    "vm.page-cluster" = 0; # 1 page per swap fault
  };

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
    git-filter-repo
    jq
    killport
    openssl
    ripgrep
    wev
    wget
    xela-utils

    ## build tools
    check
    cloc
    gcc
    gnumake
    just
    pkg-config

    ## nix-related
    attic-client
    home-manager
    nix-diff
    nixpkgs-review
    xela-nx
    xela-outdated
    # sops-build-secrets wrappers (personal + nvstly) that add formatting
    (mkSopsWrapper "sops-build-secrets" xelib.location)
    (mkSopsWrapper "sops-build-secrets-nvstly" "~/Documents/nvstly-dotfiles")

    ## editors
    nano

    ## system
    dnsutils
    e2fsprogs
    pciutils
    usbutils

    ## file management
    renameutils
    tree
    xela-download-organizer

    ## ffmpeg/typesetting/yt-dlp
    ffmpeg-full
    typst
    pandoc
    texliveSmall
    unstable.yt-dlp # this pretty much stays unstable because it needs to update quickly

    ## networking
    dig
    net-tools
    tcpdump

    ## archiving
    p7zip
    unar
    unrar
    unzip
    xela-codearchive

    ## performance
    speedtest-cli

    kitty.terminfo # needed so ssh will work from kitty
    rclone # used by some core services
    screen
  ];
  # pname => nixpkgs attr fixes for the outdated tracker
  trackPackages.aliases = {
    "1password" = "_1password-gui";
    "1password-cli" = "_1password-cli";
    Pinta = "pinta";
    attic = "attic-client";
    "bash-interactive" = "bashInteractive";
    "gcc-wrapper" = "gcc";
    garage = "garage_2";
    libreoffice = "libreoffice-qt";
    "pkg-config-wrapper" = "pkg-config";
  };

  environment.sessionVariables = {
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

  # ensure /mnt exists
  systemd.tmpfiles.rules = [ "d /mnt 0755 root root - -" ];

  # install 1password cli
  programs._1password.enable = true;
  # persist CLI config
  persist.ed.home.userFiles = [ ".config/op/config" ];

  # sops doesnt need rsa keys
  sops.gnupg.sshKeyPaths = [ ];

  # trust nixos and attic caches
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
    ]
    ++ map (a: "https://${a.domain}/${a.cacheName}") attics;
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ]
    ++ map (a: a.publicKey) attics;
  };

  # catppuccin settings
  catppuccin = {
    enable = true;
    autoEnable = false;
    inherit (xelib.globals.catppuccin) accent flavor;
  };

  persist.orphanIgnore = [ "cache" ]; # ignore cache dirs from persistence
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
  # sops needs direct access to the key if impermanence is enabled
  sops.age.sshKeyPaths = lib.mkIf (config.persist.settings.device != null) [
    "${config.persist.ed.persist.path}/etc/ssh/ssh_host_ed25519_key"
  ];
}
