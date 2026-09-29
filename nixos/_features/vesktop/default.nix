{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    (symlinkJoin {
      name = "vesktop";
      #TODO:26.11 this can probably go back to regular pkgs if its not vastly different
      paths = [ unstable.vesktop ];
      buildInputs = [ makeWrapper ];
      # add custom user agent so discord will connect through VPN
      postBuild = ''
        wrapProgram $out/bin/vesktop \
          --add-flags '--user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0"'
      '';
    })
  ];
  home-manager.importUser = [ (_: { catppuccin.vesktop.enable = true; }) ];

  persist.ed.home.userDirectories = [
    ".config/vesktop"
  ];
}
