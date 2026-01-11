{
  globals,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./common
  ];

  # Bootloader.
  #boot.loader.grub.enable = true;
  #boot.loader.grub.device = "/dev/vda";
  #boot.loader.grub.useOSProber = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "meow-pc"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Set Plasma to dark mode
  programs.dconf.enable = true;
  environment.sessionVariables = {
    PLASMA_USE_QT_SCALING = "1";
  };

  # exclude default KDE apps
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa
  ];

  # keyboard map
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # enable document printing
  services.printing.enable = true;

  # enable sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "Alex";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  programs.zsh.enable = true;

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

  # games
  programs.steam = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    # kde system utils
    kdePackages.kate
    kdePackages.kdenlive
    kdePackages.krfb
    kdePackages.partitionmanager
    kdePackages.plasma-browser-integration

    # desktop theme stuff
    (pkgs.callPackage ../lib/colloid-cursors.nix { })
    (catppuccin-kde.override {
      flavour = [ globals.catppuccin.flavor ];
      accents = [ globals.catppuccin.accent ];
      winDecStyles = [ "classic" ];
    })
    papirus-icon-theme

    # system-level apps
    chromium
    libreoffice
    vlc
  ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ username ];
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # VNC server on Tailscale
  systemd.user.services.krfb = {
    description = "KDE Remote Frame Buffer (VNC Server)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    environment = {
      DISPLAY = ":0";
    };
    serviceConfig = {
      ExecStart = "${pkgs.kdePackages.krfb}/bin/krfb --nodialog";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Tailscale System Tray
  systemd.user.services.tailscale-systray = {
    description = "Tailscale System Tray";
    wantedBy = [ "plasma-workspace.target" ];
    after = [ "plasma-workspace.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Cronjobs
  services.cron = {
    enable = true;
    systemCronJobs = [
      # "0 5 * * * root ${pkgs.rustic}/bin/rustic -P laptop backup"
    ];
  };

  # Open ports in the firewall.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    22 # SSH
    5900 # VNC
  ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

}
