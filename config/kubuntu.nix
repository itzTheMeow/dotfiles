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
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
      newsflash
    ];
    file = {

    }
    # merge in the kitty session files
    // {
      ".config/kitty/sessions/default.conf".text = ''
        cd ~
        focus
        focus_os_window
        launch
      '';
    }
    // sshConfig.kittySessions;
  };

  # create kitty ssh desktop files
  xdg.desktopEntries = sshConfig.desktopEntries;
}
