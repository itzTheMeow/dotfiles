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
      newsflash
      plex-desktop
      remmina

      ## games
      prismlauncher

      ## development
      mongodb-compass
      sqlitebrowser

      ### the rest of these are in nixos programs

      # for temporary nixos vm
      nbd
      qemu
      tigervnc

      # custom packages
      # codearchive requires these to be available
      python3Packages.pygments
      wkhtmltopdf
      (writeShellScriptBin "codearchive" (builtins.readFile ../scripts/codearchive.sh))
    ];

    file = {
    }
    // utils.mkSecretFile ".ssh/authorized_keys" "op://Private/kghbljh73rgjxgoyq2rr2frtaa/public key";
  };

  # create kitty ssh desktop files
  xdg.desktopEntries = sshConfig.desktopEntries;

  # 1Password autostart
  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs._1password-gui}/share/applications/1password.desktop"
    ];
  };

  programs.plasma = {
    enable = true;
    workspace = {
      cursor = {
        theme = "Colloid-cursors";
        size = 24;
      };
      lookAndFeel = "org.kde.breezedark.desktop";
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
          #"org.kde.plasma.pager"
          {
            iconTasks = {
              launchers = [ ];
            };
          }
          "org.kde.plasma.marginsseparator"
          {
            systemTray.items = {
              shown = [
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.networkmanagement"
              ];
            };
          }
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.minimizeall"
        ];
      }
    ];

    kwin.nightLight = {
      enable = true;
      mode = "location";
      location = {
        latitude = "40.39";
        longitude = "-76.84";
      };
    };
    configFile.kdeglobals.General = {
      TerminalApplication = "kitty";
      TerminalService = "kitty.desktop";
    };
  };
}
