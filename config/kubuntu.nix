{ pkgs, ... }:
let
  username = "meow";
  mkSSHDestination = name: addr: args: {
    desktopEntry = {
      type = "Application";
      name = "SSH ${name} (${addr})";
      genericName = "Terminal emulator";
      comment = "Fast, feature-rich, GPU based terminal";
      exec = "kitty --session ./sessions/ssh-${addr}.conf";
      icon = "kitty";
      categories = [
        "System"
        "TerminalEmulator"
      ];
    };
    sessionFile = {
      ".config/kitty/sessions/ssh-${addr}.conf" = {
        text = ''
          cd ~
          focus
          focus_os_window
          launch --title "${name} (${addr})" ${builtins.toString ../scripts/sshkitten} ${args}
        '';
      };
    };
  };

  sshDestinations = {
    ssh-hyzenberg = mkSSHDestination "Hyzenberg" "hyzen.xela.codes" "root@hyzen.xela.codes";
    ssh-jade = mkSSHDestination "Jade" "jade.nvst.ly" "root@jade.nvst.ly";
    ssh-netrohost = mkSSHDestination "NetroHost" "usest1.netro.host" "meow@usest1.netro.host -p 2034";
    ssh-odroid = mkSSHDestination "ODROID" "odroid.nvst.ng" "odroid@odroid.nvst.ng";
    ssh-pi = mkSSHDestination "Raspberry PI" "pi.nvst.ng" "th@pi.nvst.ng";
  };
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
    // (builtins.foldl' (acc: entry: acc // entry.sessionFile) { } (
      builtins.attrValues sshDestinations
    ));
  };

  # create kitty ssh desktop files
  xdg.desktopEntries = builtins.mapAttrs (name: entry: entry.desktopEntry) sshDestinations;
}
