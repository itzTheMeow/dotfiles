{
  config,
  host,
  pkgs-unstable,
  pkgs,
  xelib,
  xelpkgs,
  ...
}:
let
  gtk2rcPath = "gtk-2.0/gtkrc"; # custom path for gtk 2 rc file

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
    ./common/desktop.nix
    ./common/desktop-workstation.nix

    ./programs/activitywatch
    ./programs/discordchatexporter
    ./programs/logisim
    ./programs/thunderbird
    ./programs/vesktop
  ];

  home = {
    packages = with pkgs; [
      jdk21

      # desktop apps
      (pkgs.joplin-desktop.overrideAttrs (old: {
        # joplin needs to run with compatibility settings for wayland
        postFixup = (old.postFixup or "") + ''
          substituteInPlace $out/share/applications/joplin.desktop \
            --replace "Exec=joplin-desktop" "Exec=joplin-desktop --ozone-platform=wayland"
        '';
      }))
      pcloud
      remmina
      qdiskinfo

      # games
      prismlauncher

      # development
      gh
      mongodb-compass
      okteta
      sqlitebrowser
      vscode
      yaak

      # media
      (xelib.injectCursorsFHS plex-desktop)
      plexamp
      rssguard

      # editing
      blender
      footage
      gimp
      inkscape
      pkgs-unstable.mayo
      pinta
      obs-studio
      simplescreenrecorder

      # chat
      element-desktop
      teams-for-linux

      ### the rest of these are in nixos programs

      # sops-build-secrets wrapper to add formatting
      (writeShellScriptBin "sops-build-secrets" ''
        ${xelpkgs.sops-build-secrets}/bin/sops-build-secrets
        ${nodePackages.prettier}/bin/prettier --write --log-level silent /home/${host.username}/.dotfiles
      '')

      # codearchive requires these to be available
      python3Packages.pygments
      wkhtmltopdf
      (writeShellScriptBin "codearchive" (builtins.readFile ../scripts/codearchive.sh))
    ];

    file = {
      ".local/share/user-places.xbel" = {
        force = true;
        source = ./plasma/user-places.xbel;
      };
      # force overwriting the gtk2rc file
      "/home/${host.username}/.config/${gtk2rcPath}".force = pkgs.lib.mkForce true;
    }
    # remote views
    // xelib.mkRemoteView "Hyzenberg" "fish://root@hyzen.xela.codes:22/root"
    // xelib.mkRemoteView "Hyzenberg New" "fish://${xelib.hosts.hyzenberg.username}@${xelib.hosts.hyzenberg.ip}:${builtins.toString xelib.hosts.hyzenberg.ports.ssh}/home/walt"
    // mkHostRemoteView "ehrman"
    // xelib.mkRemoteView "Jade" "fish://root@jade.nvst.ly:22/"
    // xelib.mkRemoteView "NVSTly SSD" "fish://th@pi.nvst.ng:22/home/th/mnt/ssd"
    // xelib.mkRemoteView "odroid" "fish://odroid@odroid.nvst.ng:2222/"
    // xelib.mkRemoteView "Rustic Mount" "webdav://localhost:18898/"
    // xelib.mkRemoteView "WebDAV" "webdavs://files.xela.codes:443/webdav";
  };

  # GTK theme configuration
  gtk = {
    enable = true;
    gtk2.configLocation = "${config.xdg.configHome}/${gtk2rcPath}";

    theme = {
      name = "Catppuccin-GTK-Mauve-Dark"; # TODO: this cant be hardcoded
      package = pkgs-unstable.magnetic-catppuccin-gtk.override {
        accent = [ xelib.globals.catppuccin.accent ];
        shade = if xelib.globals.catppuccin.flavor == "latte" then "light" else "dark";
        size = "standard";
        tweaks = [
          "macos"
        ]
        ++ (
          if
            xelib.globals.catppuccin.flavor == "frappe" || xelib.globals.catppuccin.flavor == "macchiato"
          then
            [ xelib.globals.catppuccin.flavor ]
          else
            [ ]
        );
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = xelib.globals.cursors;
    font = {
      name = "Noto Sans";
      size = 10;
    };
    gtk4.theme = config.gtk.theme;

    /*
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-button-images = true;
        gtk-cursor-blink = true;
        gtk-cursor-blink-time = 1000;
        gtk-decoration-layout = "icon:minimize,maximize,close";
        gtk-enable-animations = true;
        gtk-menu-images = true;
        gtk-modules = "colorreload-gtk-module";
        gtk-primary-button-warps-slider = true;
        gtk-sound-theme-name = "ocean";
        gtk-toolbar-style = 3;
        gtk-xft-dpi = 98304;
      };

      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-cursor-blink = true;
        gtk-cursor-blink-time = 1000;
        gtk-decoration-layout = "icon:minimize,maximize,close";
        gtk-enable-animations = true;
        gtk-primary-button-warps-slider = true;
        gtk-sound-theme-name = "ocean";
        gtk-xft-dpi = 98304;
      };
    */
  };

  # set default browser to Firefox Developer Edition
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox-devedition.desktop";
      "x-scheme-handler/http" = "firefox-devedition.desktop";
      "x-scheme-handler/https" = "firefox-devedition.desktop";
      "x-scheme-handler/about" = "firefox-devedition.desktop";
      "x-scheme-handler/unknown" = "firefox-devedition.desktop";
    };
  };

  # 1Password autostart
  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs-unstable._1password-gui}/share/applications/1password.desktop"
      "${pkgs.pcloud}/share/applications/pcloud.desktop"
    ];
  };

  # KDE Plasma settings
  programs.plasma = {
    enable = true;
    workspace = {
      cursor = {
        theme = xelib.globals.cursors.name;
        inherit (xelib.globals.cursors) size;
      };
      #lookAndFeel = "org.kde.breezedark.desktop";
      iconTheme = "Papirus-Dark";
      theme = "Catppuccin-${xelib.toTitleCase xelib.globals.catppuccin.flavor}-${xelib.toTitleCase xelib.globals.catppuccin.accent}";
      colorScheme = "Catppuccin${xelib.toTitleCase xelib.globals.catppuccin.flavor}${xelib.toTitleCase xelib.globals.catppuccin.accent}";
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__Catppuccin${xelib.toTitleCase xelib.globals.catppuccin.flavor}-Classic";
      };
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
        mode = "automatic";
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
    # make baloo ignore pcloud mount
    configFile."baloofilerc"."General"."exclude folders" = "/home/${host.username}/pCloudDrive";

    # Power management settings
    powerdevil = {
      AC = {
        autoSuspend = {
          action = "nothing"; # Never suspend on AC power
        };
        turnOffDisplay = {
          idleTimeout = "never"; # Keep display on while on AC
        };
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
    };
  };
}
