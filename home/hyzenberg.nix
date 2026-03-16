{ ... }:
{
  imports = [
    ./common
    ./common/headless.nix

    ./programs/rclone
  ];

  home = { };
}
