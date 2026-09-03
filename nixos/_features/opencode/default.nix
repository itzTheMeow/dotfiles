{ pkgs-unstable, ... }: {
  #TODO:26.11 swap to regular
  environment.systemPackages = with pkgs-unstable; [ opencode ];

  persist.ed.home.userDirectories = [
    ".config/opencode"
    #".local/share/opencode"
  ];
}
