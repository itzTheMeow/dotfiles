{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";
    opinject.url = "github:itzTheMeow/opinject";
    #opnix.url = "github:itzTheMeow/opnix/a18b32d338d2316f12afe8c694525f1ef5b01c75";
  };

  outputs =
    {
      catppuccin,
      home-manager,
      nixpkgs,
      opinject,
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
            config.allowUnfree = true;

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
            catppuccin.homeModules.catppuccin
            opinject.homeManagerModules.default
            ./home/${hostname}.nix
          ];

          extraSpecialArgs = {
            inherit inputs hostname home-manager;
            utils = import ./lib/utils.nix;
          };
        };
      mkNixosConfiguration =
        hostname:
        nixpkgs.lib.nixosSystem {
          modules = [
            catppuccin.nixosModules.catppuccin
            ./nixos/${hostname}.nix
          ];
          specialArgs = {
            inherit inputs hostname;
            utils = import ./lib/utils.nix;
          };
        };
    in
    {
      homeConfigurations = {
        laptop = mkHomeConfiguration linux "laptop";

        hyzenberg = mkHomeConfiguration linux "hyzenberg";
        netrohost = mkHomeConfiguration linux "netrohost";

        macintosh = mkHomeConfiguration darwin "macintosh";
      };

      nixosConfigurations = {
        laptop = mkNixosConfiguration "laptop";
      };
    };
}
