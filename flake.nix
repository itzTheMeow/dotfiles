{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";
    opnix.url = "github:brizzbuzz/opnix";
  };

  outputs =
    {
      catppuccin,
      home-manager,
      nixpkgs,
      opnix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      mkHomeConfiguration =
        hostname:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [
            opnix.homeManagerModules.default
            catppuccin.homeModules.catppuccin
            ./config/${hostname}.nix
          ];

          extraSpecialArgs = {
            inherit inputs hostname;
          };
        };
    in
    {
      homeConfigurations = {
        kubuntu = mkHomeConfiguration "kubuntu";
        hyzenberg = mkHomeConfiguration "hyzenberg";
      };
    };
}
