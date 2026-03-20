# any device with a gui
{ pkgs, xelib, ... }:
{
  environment.systemPackages = with pkgs; [
    # desktop themeing
    xelib.globals.cursors.package
    papirus-icon-theme
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
  };

  # enable bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # keymapper
  services.keyd = {
    enable = true;
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
}
