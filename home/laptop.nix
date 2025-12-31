{ pkgs, utils, ... }:
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
      cubiomes-viewer

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

  programs.plasma = {
    enable = true;
    workspace = {
      cursor = {
        theme = "Colloid-cursors";
        size = 24;
      };
      theme = "catppuccin-mocha-mauve";
      colorScheme = "catppuccinMochaMauve";
    };
    panels = [
      {
        location = "top";
        height = 24;
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.minimizeall"
        ];
      }
    ];
  };
}
