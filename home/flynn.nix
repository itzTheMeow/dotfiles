{
  pkgs,
  xelib,
  ...
}:
let
  # shorthand to create a remote view for a specific defined host
  mkHostRemoteView =
    name:
    let
      host = xelib.hosts.${name};
    in
    xelib.mkRemoteView (xelib.toTitleCase name) "fish://${host.username}@${host.ip}:${toString host.ports.ssh}/home/${host.username}";
in
{
  imports = [
    ./common
  ];

  home = {
    packages = with pkgs; [
      # development
      figma-linux
      gh
      mongodb-compass
      okteta
      sqlitebrowser
      yaak

      # media
      (xelib.injectCursorsFHS plex-desktop)
      plexamp

      # editing
      blender
      footage
      gimp
      inkscape
      mayo
      pinta
      obs-studio

      # chat
      element-desktop
    ];

    file = {
      ".local/share/user-places.xbel" = {
        force = true;
        source = ./plasma/user-places.xbel;
      };
    }
    # remote views
    // mkHostRemoteView "pete"
    // mkHostRemoteView "hyzenberg"
    // mkHostRemoteView "ehrman"
    // xelib.mkRemoteView "Jade" "fish://root@jade.nvst.ly:22/"
    // xelib.mkRemoteView "NVSTly SSD" "fish://th@pi.nvst.ng:22/home/th/mnt/ssd"
    // xelib.mkRemoteView "odroid" "fish://odroid@odroid.nvst.ng:2222/"
    // xelib.mkRemoteView "Rustic Mount" "webdav://localhost:18898/"
    // xelib.mkRemoteView "WebDAV" "webdavs://webdav.xela:443/";
  };

  # GTK theme configuration
  gtk = {
    enable = true;
    iconTheme = xelib.globals.icons;
    cursorTheme = xelib.globals.cursors;
    font = {
      name = xelib.globals.fonts.system.name;
      size = 10;
    };
  };

  # KDE Plasma settings
  programs.plasma = {
    enable = true;
    overrideConfig = true;
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
    workspace = {
      cursor = {
        theme = xelib.globals.cursors.name;
        inherit (xelib.globals.cursors) size;
      };
      #lookAndFeel = "org.kde.breezedark.desktop";
      iconTheme = xelib.globals.icons.name;
      theme = "Catppuccin-${xelib.toTitleCase xelib.globals.catppuccin.flavor}-${xelib.toTitleCase xelib.globals.catppuccin.accent}";
      colorScheme = "Catppuccin${xelib.toTitleCase xelib.globals.catppuccin.flavor}${xelib.toTitleCase xelib.globals.catppuccin.accent}";
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__Catppuccin${xelib.toTitleCase xelib.globals.catppuccin.flavor}-Classic";
      };
    };
    fonts =
      let
        mkFont = pointSize: {
          family = xelib.globals.fonts.system.name;
          inherit pointSize;
        };
      in
      {
        general = mkFont 10;
        fixedWidth = {
          family = xelib.globals.fonts.terminal.name;
          pointSize = 10;
        };
        small = mkFont 8;
        toolbar = mkFont 10;
        menu = mkFont 10;
        windowTitle = mkFont 10;
      };
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
    session = {
      general.askForConfirmationOnLogout = false; # dont prompt for 30 seconds on logout/shutdown
      sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession"; # dont restore apps on signin
    };

    input.keyboard = {
      numlockOnStartup = "on";
      # enable use of extended function keys
      options = [ "fkeys:basic_13-24" ];
    };
    shortcuts = {
      kwin = {
        Overview = "Meta+Space";
        "Walk Through Windows" = "Alt+`";
        "Walk Through Windows (Reverse)" = "Alt+~";
        "Walk Through Windows Alternative" = "Alt+Tab";
        "Walk Through Windows Alternative (Reverse)" = "Alt+Shift+Tab";
        "Walk Through Windows of Current Application" = [ ];
        "Walk Through Windows of Current Application (Reverse)" = [ ];
        "Window Close" = [
          "Alt+F4"
          "F24"
        ];
      };
      "org.kde.spectacle.desktop" = {
        RectangularRegionScreenShot = [
          "Meta+Shift+S"
          "Print"
        ];
        _launch = "Meta+Shift+Print";
      };
    };

    kwin = {
      nightLight = {
        enable = true;
        mode = "location";
        location = {
          latitude = "40.39";
          longitude = "-76.84";
        };
      };
      titlebarButtons = {
        left = [
          "more-window-actions"
          "keep-above-windows"
        ];
        right = [
          "help"
          "minimize"
          "maximize"
          "close"
        ];
      };
    };
    # disable screen edge effects
    configFile.kwinrc."Effect-overview".BorderActivate = "9";
    # change tab menu to sidebar
    configFile.kwinrc.TabBox.LayoutName = "sidebar";
    # allow unattended access for krfb
    configFile."krfbrc"."Security"."allowUnattendedAccess" = "true";
    # turn on do not disturb (set year to 3000)
    configFile.plasmanotifyrc.DoNotDisturb.Until = "3000,1,1,1,1,1";

    # Power management settings
    powerdevil = {
      AC = {
        autoSuspend.action = "nothing"; # Never suspend on AC power
        turnOffDisplay.idleTimeout = "never"; # Keep display on while on AC
        whenLaptopLidClosed = "doNothing";
      };
      battery = {
        autoSuspend = {
          action = "sleep"; # Suspend when on battery
          idleTimeout = 1800; # 30 minutes in seconds
        };
      };
    };

    kscreenlocker = {
      autoLock = true; # enable auto screen lock
      lockOnResume = true; # lock screen on wake
      timeout = 10; # lock after 10min
      passwordRequiredDelay = 5; # password required 5sec after locking
    };

    # set default terminal to kitty
    configFile.kdeglobals.General = {
      TerminalApplication = "kitty";
      TerminalService = "kitty.desktop";
    };
    # for some reason this doesnt work properly
    dataFile = {
      #"dolphin/view_properties/global/.directory".Dolphin.ViewMode = 1; # icons
      #"dolphin/view_properties/global/.directory".Dolphin.VisibleRoles =
      #  "Icons_text,Icons_size,Icons_modificationtime"; # add additional info to files
      #"dolphin/view_properties/global/.directory".Settings.AdditionalInfo = 2; # show additional information rows under filenames (0=none, 1=some, 2=all)
    };
    configFile.dolphinrc = {
      General = {
        ShowFullPath = true; # show full path in top bar
        ShowStatusBar = "FullWidth"; # make bottom status bar full width
        ShowZoomSlider = true; # show zoom slider in bottom status bar
      };
      ContextMenu.ShowOpenTerminal = false;
    };
  };
}
