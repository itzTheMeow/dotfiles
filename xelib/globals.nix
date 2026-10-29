{ pkgs, ... }:
{
  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
  cursors = {
    name = "Colloid-cursors";
    size = 24;
    #TODO:26.11
    package = pkgs.unstable.colloid-cursors;
  };
  icons = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };
  fonts = {
    system = {
      name = "Noto Sans";
      package = pkgs.noto-fonts;
      size = 10; # just the default for KDE so we use it everywhere
    };
    code = {
      name = "CommitMono";
      package = pkgs.commit-mono;
    };
    terminal = {
      name = "CaskaydiaMono Nerd Font Mono";
      package = pkgs.nerd-fonts.caskaydia-mono;
    };
  };
  # proxy IP ranges to trust
  trustedProxies = [
    "127.0.0.0/8"
    "::1/128"
    "100.64.0.0/10"
  ];
}
