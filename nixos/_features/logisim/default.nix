{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.logisim ];
  # register mimetype for .circ files
  home-manager.importUser = [
    (_: {
      home.file.".local/share/mime/packages/x-logisim.xml".source = ./x-logisim.xml;
      xdg.mimeApps.defaultApplications."application/x-logisim-circuit" = "logisim.desktop";
    })
  ];
}
