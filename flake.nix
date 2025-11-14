{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      homeConfigurations = {
        kubuntu = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./config
            ./config/computers
            ./config/computers/kubuntu.nix
          ];
        };

        hyzenberg = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./config
            ./config/hyzenberg.nix
          ];
        };
      };
    };
}
