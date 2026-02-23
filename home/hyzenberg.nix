{
  xelpkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    packages = [
      xelpkgs.rustic-unstable
    ];
  };
}
