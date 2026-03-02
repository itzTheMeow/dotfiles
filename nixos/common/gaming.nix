{
  pkgs,
  xelpkgs,
  ...
}:
{
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # steam needs access to the cursor theme
      extraPkgs = _: [
        xelpkgs.colloid-cursors
      ];
    };
  };

  environment.systemPackages = [ xelpkgs.game-hells-kitchen ];
}
