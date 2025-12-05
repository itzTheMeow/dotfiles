{ pkgs, utils, ... }:
let
  username = "meow";
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
      newsflash
      plex-desktop

      nbd
      qemu
      tigervnc
    ];
  };

  # create kitty ssh desktop files
  xdg.desktopEntries = sshConfig.desktopEntries;
}
