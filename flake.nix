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
      linux = "x86_64-linux";
      darwin = "x86_64-darwin";
      mkHomeConfiguration =
        system: hostname:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;

            # fix fish on macos
            overlays = [
              (
                final: prev:
                if prev.stdenv.isDarwin then
                  {
                    fish = prev.fish.overrideAttrs (_: {
                      doCheck = false;
                    });
                  }
                else
                  { }
              )
            ];
          };

          modules = [
            opnix.homeManagerModules.default
            catppuccin.homeModules.catppuccin
            ./config/${hostname}.nix
          ];

          extraSpecialArgs = {
            inherit inputs hostname;
            utils = import ./lib/utils.nix;
          };
        };
    in
    {
      homeConfigurations = {
        hyzenberg = mkHomeConfiguration linux "hyzenberg";
        kubuntu = mkHomeConfiguration linux "kubuntu";
        netrohost = mkHomeConfiguration linux "netrohost";

        macintosh = mkHomeConfiguration darwin "macintosh";
      };
    };
}
