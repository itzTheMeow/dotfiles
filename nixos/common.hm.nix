{ config, xelib, ... }: {
  home.stateVersion = "25.11"; # not to be changed
  #TODO:pr https://github.com/nix-community/home-manager/pull/8865 i insist - this can be disabled once merged
  home.enableNixpkgsReleaseCheck = false;
  programs.home-manager.enable = true; # manage itself

  # configure SOPS user key if present
  sops.age =
    if ((config.sops.groupPaths ? system) && (config.sops.groupPaths.system ? user-key)) then
      { sshKeyPaths = [ config.sops.groupPaths.system.user-key ]; }
    else
      # effectively disable
      { keyFile = "/dev/null"; };

  home.shellAliases = {
    # basic
    ls = "ls --color=auto";
    la = "ls -A";
    ll = "ls -alF";
    grep = "grep --color=auto";
    txz = "tar -cJf";
    qmv = "qmv -ospaces"; # use spaces for qmv
    cdtemp = "cd $(mktemp -d) && pwd";

    # shortcuts
    sc = "sudo systemctl";
    scu = "systemctl --user";
  };

  # catppuccin settings
  catppuccin = {
    enable = true;
    autoEnable = false;
    inherit (xelib.globals.catppuccin) accent flavor;
  };
}
