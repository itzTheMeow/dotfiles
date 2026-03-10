{ pkgs, ... }:
{
  imports = [
    ./common
    ./common/desktop.nix

    ./programs/rclone
  ];

  home = {
    packages = with pkgs; [
      plex-desktop
      plexamp
    ];
  };
}
