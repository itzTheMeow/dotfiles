{
  xelpkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix

    ./programs/rclone
  ];

  home = {
    packages = [
      xelpkgs.rustic-unstable
    ];
  };
}
