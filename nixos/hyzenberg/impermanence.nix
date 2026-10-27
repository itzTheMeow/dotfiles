{ ... }:
{
  persist.ed.lib = {
    directories = [ "var/lib" ];
    compression = 1;
  };

  persist.ed.home = {
    directories = [ "/home/meow" ];
    userDirectories = [
      ".local"
    ];
  };
}
