{
  globals,
  pkgs,
  utils,
  ...
}:
let
  username = "xela";
  sshConfig = import ./common/ssh.nix { inherit pkgs utils; };
in
{
  imports = [
    ./common
    ./common/desktop.nix
    ./programs/discordchatexporter
    ./programs/logisim
    ./programs/plexamp
    ./programs/thunderbird
    ./programs/vesktop
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    sessionVariables = {
      GTK_USE_PORTAL = "1";
      QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
    };

    packages = with pkgs; [
      jdk21

      # desktop apps
      joplin-desktop
      pcloud
      remmina

      ## games
      prismlauncher

      ## development
      mongodb-compass
      okteta
      sqlitebrowser
      vscode
      yaak

      ## media
      newsflash
      plex-desktop

      ## editing
      footage
      gimp
      pinta
      obs-studio
      simplescreenrecorder

      ### the rest of these are in nixos programs

      # custom packages
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
    // utils.mkSecretFile ".ssh/authorized_keys" "op://Private/kghbljh73rgjxgoyq2rr2frtaa/public key";
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
      "${pkgs.tailscale}/share/applications/tailscale-systray.desktop"
    ];
  };

  programs.plasma = {
    enable = true;
    workspace = {
      cursor = {
        theme = "Colloid-cursors";
        size = 24;
      };
      #lookAndFeel = "org.kde.breezedark.desktop";
      iconTheme = "Papirus-Dark";
      theme = "Catppuccin-${utils.toTitleCase globals.catppuccin.flavor}-${utils.toTitleCase globals.catppuccin.accent}";
      colorScheme = "Catppuccin${utils.toTitleCase globals.catppuccin.flavor}${utils.toTitleCase globals.catppuccin.accent}";
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__Catppuccin${utils.toTitleCase globals.catppuccin.flavor}-Classic";
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

    kwin.nightLight = {
      enable = true;
      mode = "location";
      location = {
        latitude = "40.39";
        longitude = "-76.84";
      };
    };

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
    # set visible columns on files
    dataFile = {
      "dolphin/view_properties/global/.directory".Dolphin.VisibleRoles =
        "Icons_text,Icons_size,Icons_modificationtime";
    };
  };
}
