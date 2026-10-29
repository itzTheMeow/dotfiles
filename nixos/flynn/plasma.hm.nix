{ pkgs, ... }: {
  programs.plasma = {
    launcherFavorites = [
      "applications:kitty.desktop"
      "applications:org.kde.dolphin.desktop"
      "preferred://browser"
      "applications:chromium-browser.desktop"

      "applications:vesktop.desktop"
      "applications:thunderbird.desktop"
      "applications:siyuan.desktop"
      "applications:timefinder-electron.desktop"

      "applications:dev.zed.Zed.desktop"
      "applications:org.pegasus_frontend.Pegasus"
      "applications:steam.desktop"
      "applications:org.prismlauncher.PrismLauncher.desktop"

      "applications:chrome-gfgbgjphjkdhefmnmbhogcpckgpapbag-Default.desktop" # Snapchat Web
      "applications:systemsettings.desktop"
      "applications:org.kde.plasma-systemmonitor.desktop"
      "applications:plexamp.desktop"
    ];
    panels = [
      {
        location = "top";
        height = 24;
        widgets = [
          {
            kickoff = {
              showButtonsFor.custom = [
                "lock-screen"
                "logout"
                "reboot"
                "shutdown"
              ];
            };
          }
          {
            iconTasks.launchers = [ ];
          }
          "org.kde.plasma.marginsseparator"
          {
            systemTray.items = {
              hidden = [
                "Fcitx"
                "org.kde.plasma.brightness"
                "org.kde.plasma.nightcolorcontrol"
                "org.kde.kupapplet"
                "xdg-desktop-portal-kde" # remote control icon
              ];
              configs = {
                battery.showPercentage = true;
                # makes keyboard indicator show numlock
                "org.kde.plasma.keyboardindicator".config.General.key = "Caps Lock,Num Lock";
              };
            };
          }
          {
            name = "com.dschopf.plasma.qalculate";
            config = {
              Currency = {
                updateExchangeRatesAtStartup = true;
                updateExchangeRatesRegularly = true;
              };
              General = {
                launcherEnabled = true;
                launcherExecutable = "${pkgs.qalculate-qt}/bin/qalculate-qt";
                #libVersion = 552;
                liveEvaluation = true;
                qalculateIcon = "gnome-calculator-symbolic";
              };
            };
          }
          {
            digitalClock.timeZone = {
              selected = [
                "America/Los_Angeles"
                "Local"
                "Europe/London"
              ];
              lastSelected = "Local";
            };
          }
          "org.kde.plasma.minimizeall"
        ];
      }
    ];
    # turn on do not disturb (set year to 3000)
    configFile.plasmanotifyrc.DoNotDisturb.Until = "3000,1,1,1,1,1";
  };
}
