# various tools for ios devices
{ pkgs, ... }: {
  environment.systemPackages =
    with pkgs;
    [
      libimobiledevice
      ideviceinstaller
      ifuse
    ]
    #TODO:26.11 stable
    ++ lib.optional (!(builtins.elem "console" host.type)) pkgs.unstable.palera1n;
}
