{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  colloid-cursors = pkgs.callPackage ./colloid-cursors.nix { };
  download-organizer = pkgs.callPackage ./download-organizer.nix { };
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
  sops-build-secrets = pkgs.callPackage ./sops-build-secrets.nix {
    inherit (pkgs-unstable) _1password-gui;
  };
}
