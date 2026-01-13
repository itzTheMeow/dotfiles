{
  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
  environment = {
    GSK_RENDERER = "cairo"; # force software rendering for GTK4 (fixes graphical issues)
    GTK_USE_PORTAL = "1";
    PLASMA_USE_QT_SCALING = "1";
  };
}
