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
      jdk21

      # desktop apps
      newsflash
      plex-desktop

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
}
