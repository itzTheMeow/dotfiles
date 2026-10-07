{
  host,
  lib,
  pkgs,
  xelib,
  ...
}:
{
  imports =
    (xelib.umport { path = ./programs; })
    ++ lib.optional (!(builtins.elem "console" host.type)) ./not-console.nix;

  environment.systemPackages = with pkgs; [
    # desktop themeing
    xelib.globals.cursors.package
    papirus-icon-theme

    # base gui apps
    qalculate-qt
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

  # enable usbmuxd service
  services.usbmuxd.enable = true;

  # fonts
  fonts = {
    fontconfig.enable = true;
    packages =
      (with pkgs; [
        corefonts
        montserrat
      ])
      ++ (map (f: f.package) (builtins.attrValues xelib.globals.fonts));
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

  services.tailscale = {
    # enable usage of exit nodes
    useRoutingFeatures = "client";
    # allow LAN access (helps with 30sec takedown time)
    extraSetFlags = [ "--exit-node-allow-lan-access" ];
  };

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
