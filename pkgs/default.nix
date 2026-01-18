{ pkgs, ... }:
{
  colloid-cursors = pkgs.callPackage ./colloid-cursors.nix { };
  magnetic-catppuccin-gtk = pkgs.callPackage ./magnetic-catppuccin-gtk.nix { };
  plasma-bigscreen = pkgs.callPackage ./plasma-bigscreen.nix {
    inherit (pkgs.kdePackages)
      kcmutils
      kdeclarative
      ki18n
      kio
      knotifications
      kwayland
      kwindowsystem
      mkKdeDerivation
      qtmultimedia
      plasma-workspace
      bluez-qt
      qtwebengine
      plasma-nano
      plasma-nm
      milou
      kscreen
      kdeconnect-kde
      ;
  };
  rustic-unstable = pkgs.callPackage ./rustic-unstable.nix { };
}
