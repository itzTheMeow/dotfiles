{ xelib, ... }:
let
  catFlavor = xelib.toTitleCase xelib.globals.catppuccin.flavor;
  catAccent = xelib.toTitleCase xelib.globals.catppuccin.accent;

  systemFont = {
    family = xelib.globals.fonts.system.name;
    pointSize = xelib.globals.fonts.system.size;
  };
in
{
  programs.plasma = {
    enable = true;
    overrideConfig = true;

    workspace = {
      # use global theme packages
      cursor = {
        theme = xelib.globals.cursors.name;
        inherit (xelib.globals.cursors) size;
      };
      iconTheme = xelib.globals.icons.name;
      #TODO:(idk) lookAndFeel = "org.kde.breezedark.desktop";

      # enable catppuccin themes
      theme = "Catppuccin-${catFlavor}-${catAccent}";
      colorScheme = "Catppuccin${catFlavor}${catAccent}";
      # enable the "classic" min/max/close buttons from the theme
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__Catppuccin${catFlavor}-Classic";
      };
    };

    # use the global system font
    fonts = {
      general = systemFont;
      fixedWidth = {
        family = xelib.globals.fonts.terminal.name;
        pointSize = xelib.globals.fonts.system.size;
      };
      small = systemFont // {
        pointSize = 8;
      };
      toolbar = systemFont;
      menu = systemFont;
      windowTitle = systemFont;
    };

    session = {
      general.askForConfirmationOnLogout = false; # dont prompt for 30 seconds on logout/shutdown
      sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession"; # dont restore apps on signin
    };

    kwin = {
      # enable nightLight for my rough location
      nightLight = {
        enable = true;
        mode = "location";
        location = {
          latitude = "40.39";
          longitude = "-76.84";
        };
      };
      # configure title bar buttons
      titlebarButtons = {
        left = [
          "more-window-actions"
          "keep-above-windows" # "pin" button
        ];
        right = [
          "help"
          "minimize"
          "maximize"
          "close"
        ];
      };
    };

    input.keyboard = {
      numlockOnStartup = "on";
      options = [ "fkeys:basic_13-24" ]; # enable use of extended function keys
    };

    # disable screen edge effects
    configFile.kwinrc."Effect-overview".BorderActivate = "9";
    # allow unattended access for krfb
    configFile."krfbrc"."Security"."allowUnattendedAccess" = "true";

    #TODO: for some reason this doesnt work properly
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
