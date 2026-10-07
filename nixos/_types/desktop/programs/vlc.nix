{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.vlc ];

  # disable VLC metadata prompt on startup
  home-manager.importUser = [
    (_: {
      xdg.configFile."vlc/vlcrc".text = ''
        [qt]
        qt-privacy-ask=0
        [core]
        metadata-network-access=1
      '';
    })
  ];
}
