{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opnix.url = "github:brizzbuzz/opnix";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      opnix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      homeConfigurations = {
        kubuntu = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            opnix.homeManagerModules.default
            ./config
            ./config/computers
            ./config/computers/kubuntu.nix
          ];
        };

        hyzenberg = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            opnix.homeManagerModules.default
            ./config
            ./config/hyzenberg.nix
          ];
        };
      };
    };
}
