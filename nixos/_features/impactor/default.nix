{ pkgs, ... }: {
  #TODO:26.11 stable
  environment.systemPackages = [ pkgs.unstable.impactor ];
}
