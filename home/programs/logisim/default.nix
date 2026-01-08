{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      logisim
    ];

    # register mimetype for .circ files
    file.".local/share/mime/packages/x-logisim.xml".source = ./x-logisim.xml;
  };
  xdg.mimeApps.defaultApplications."application/x-logisim-circuit" = "logisim.desktop";
}
