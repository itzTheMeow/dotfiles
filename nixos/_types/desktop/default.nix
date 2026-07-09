{
  host,
  lib,
  pkgs,
  xelib,
  ...
}:
{
  imports = lib.optional (!(builtins.elem "console" host.type)) ./not-console.nix;

  environment.systemPackages = with pkgs; [
    # desktop themeing
    xelib.globals.cursors.package
    papirus-icon-theme

    # base gui apps
    qalculate-qt
    vlc
  ];

  services.xserver = {
    enable = true;
    # keyboard map
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # enable sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # enable bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # hardware accel
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # fonts
  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      nerd-fonts.caskaydia-mono
      corefonts
      montserrat
    ];
  };

  # keymapper
  services.keyd = {
    enable = true;
    # wireless tv remote
    keyboards.remotecontrol = {
      ids = [ "1915:1001" ];
      settings.main = {
        voicecommand = "f24"; # re-bind the voice command button to F24
      };
    };
  };

  # enable usage of exit nodes for tailscale
  services.tailscale.useRoutingFeatures = "client";

  # tailscale system tray
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

  persist.ed.home = {
    userDirectories = [
      ".config/session" # used by apps to store session data
    ];
    userFiles = [
      "Desktop/.directory" # only keep the fact that it exists. nothing on desktop is kept
    ];
  };
}
