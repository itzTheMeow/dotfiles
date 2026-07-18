{ pkgs-unstable, ... }:
{
  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
  cursors = {
    name = "Colloid-cursors";
    size = 24;
    #TODO:26.11
    package = pkgs-unstable.colloid-cursors;
  };
  # proxy IP ranges to trust
  trustedProxies = [
    "127.0.0.0/8"
    "::1/128"
    "100.64.0.0/10"
  ];
  environment = {
    GSK_RENDERER = "cairo"; # force software rendering for GTK4 (fixes graphical issues)
    GTK_USE_PORTAL = "1";
    NTFY_TOPIC = "ntfy.xela.codes/meow";
    PLASMA_USE_QT_SCALING = "1";
  };
}
