{
  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
  environment = {
    GSK_RENDERER = "cairo"; # force software rendering for GTK4 (fixes graphical issues)
    GTK_USE_PORTAL = "1";
    NTFY_TOPIC = "ntfy.xela.codes/meow";
    PLASMA_USE_QT_SCALING = "1";
  };
}
