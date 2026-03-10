{ ... }:
{
  imports = [
    ./common
    ./common/desktop.nix

    ./programs/rclone
  ];

  home = {
    # ...
  };
}
