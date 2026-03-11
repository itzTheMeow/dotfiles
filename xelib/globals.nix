{ xelpkgs, ... }:
{
  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
  cursors = {
    name = "Colloid-cursors";
    size = 24;
    package = xelpkgs.colloid-cursors;
  };
  environment = {
    GSK_RENDERER = "cairo"; # force software rendering for GTK4 (fixes graphical issues)
    GTK_USE_PORTAL = "1";
    NTFY_TOPIC = "ntfy.xela.codes/meow";
    PLASMA_USE_QT_SCALING = "1";
  };
}
