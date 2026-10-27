{
  xelib,
  ...
}:
{
  persist.ed.lib = {
    directories = [ "var/lib" ];
    compression = 1;
    compressForce = true;
  };

  persist.ed.home = {
    directories = [ "/home/meow" ];
    userDirectories = [
      xelib.locationDir
      ".local"
    ];
  };
}
