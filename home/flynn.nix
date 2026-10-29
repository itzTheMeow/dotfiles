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

      # editing
      blender
      footage
      gimp
      inkscape
      mayo
      pinta
      obs-studio
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

  # KDE Plasma settings
  programs.plasma = {
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

    # change tab menu to sidebar
    configFile.kwinrc.TabBox.LayoutName = "sidebar";

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
  };
}
