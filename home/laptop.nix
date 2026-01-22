{
  config,
  pkgs,
  xelib,
  xelpkgs,
  ...
}:
let
  username = "xela";
  sshConfig = import ./common/ssh.nix { inherit pkgs xelib; };
in
{
  imports = [
    ./common
    ./common/desktop.nix
    ./programs/activitywatch
    ./programs/discordchatexporter
    ./programs/discord-rich-presence-plex
    ./programs/logisim
    ./programs/plexamp
    ./programs/thunderbird
    ./programs/vesktop
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    sessionVariables = {
      NTFY_TAGS = "meow-pc";
    };

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
      plex-desktop
      rssguard

      # editing
      footage
      gimp
      inkscape
      pinta
      obs-studio
      simplescreenrecorder

      ### the rest of these are in nixos programs

      # custom packages
      xelpkgs.rustic-unstable
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
    }
    # secrets
    // xelib.mkSecretFile ".ssh/authorized_keys" "op://Private/kghbljh73rgjxgoyq2rr2frtaa/public key"
    // xelib.mkSecretFile ".config/ntfy/client.yml" "default-token: op://Private/ntfy/Access Tokens/hwqse4uueo5q5mh6ffik5oiyym"
    // xelib.mkSecretFile ".local/share/beszel/env" "TOKEN=\"op://Private/xoznbnccpqcu2pbzonqxih2tba/password\""
    # opunattended secrets
    // xelib.mkOPUnattendedSecret "op://Private/6z2tlumg4aiznrno7mnryjunsq/password"
    # remote views
    // xelib.mkRemoteView "Hyzenberg" "fish://root@hyzen.xela.codes:22/root"
    // xelib.mkRemoteView "Jade" "fish://root@jade.nvst.ly:22/"
    // xelib.mkRemoteView "NVSTly SSD" "fish://th@pi.nvst.ng:22/home/th/mnt/ssd"
    // xelib.mkRemoteView "odroid" "fish://odroid@odroid.nvst.ng:2222/"
    // xelib.mkRemoteView "Rustic Mount" "webdav://localhost:18898/"
    // xelib.mkRemoteView "WebDAV" "webdavs://files.xela.codes:443/webdav";
  };

  # GTK theme configuration
  gtk = {
    enable = true;

    # prevent KDE from overwriting GTK config
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";

    theme = {
      name = "Catppuccin-GTK-Mauve-Dark"; # TODO: this cant be hardcoded
      package = xelpkgs.magnetic-catppuccin-gtk.override {
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
    cursorTheme = {
      name = "Colloid-cursors";
      size = 24;
      package = xelpkgs.colloid-cursors;
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };

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

  # create kitty ssh desktop files
  xdg.desktopEntries = sshConfig.desktopEntries;

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
      "${pkgs._1password-gui}/share/applications/1password.desktop"
      "${pkgs.pcloud}/share/applications/pcloud.desktop"
    ];
  };

  # KDE Plasma settings
  programs.plasma = {
    enable = true;
    workspace = {
      cursor = {
        theme = "Colloid-cursors";
        size = 24;
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
          "org.kde.plasma.kickoff"
          {
            iconTasks = {
              launchers = [ ];
            };
          }
          "org.kde.plasma.marginsseparator"
          {
            systemTray.items = {
              hidden = [
                "Fcitx"
                "org.kde.plasma.brightness"
                "org.kde.plasma.nightcolorcontrol"
                "org.kde.kupapplet"
              ];
            };
          }
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.minimizeall"
        ];
      }
    ];
    session = {
      general.askForConfirmationOnLogout = false; # dont prompt for 30 seconds on logout/shutdown
      sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession"; # dont restore apps on signin
    };

    shortcuts = {
      kwin.Overview = "Meta+Space";
      kwin."Walk Through Windows" = "Alt+`";
      kwin."Walk Through Windows (Reverse)" = "Alt+~";
      kwin."Walk Through Windows Alternative" = "Alt+Tab";
      kwin."Walk Through Windows Alternative (Reverse)" = "Alt+Shift+Tab";
      kwin."Walk Through Windows of Current Application" = [ ];
      kwin."Walk Through Windows of Current Application (Reverse)" = [ ];
      "org.kde.spectacle.desktop".RectangularRegionScreenShot = [
        "Meta+Shift+S"
        "Print"
      ];
      "org.kde.spectacle.desktop"._launch = "Meta+Shift+Print";
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
