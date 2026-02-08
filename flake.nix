{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    opinject = {
      url = "github:itzTheMeow/opinject";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    headplane = {
      url = "github:tale/headplane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      catppuccin,
      headplane,
      home-manager,
      nixpkgs-unstable,
      nixpkgs,
      opinject,
      plasma-manager,
      ...
    }@inputs:
    let
      home-manager-modules = [
        catppuccin.homeModules.catppuccin
        plasma-manager.homeModules.plasma-manager
        opinject.homeManagerModules.default
      ];

      mkHomeConfiguration =
        system: hostname:
        let
          pkgs-unstable = nixpkgs-unstable.legacyPackages.${builtins.elemAt system 0};
        in
        home-manager.lib.homeManagerConfiguration rec {
          pkgs = nixpkgs.legacyPackages.${builtins.elemAt system 0};

          modules = home-manager-modules ++ [
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [
                (
                  final: prev: # fixes fish on macos
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
            }
            ./home/${hostname}.nix
          ];

          extraSpecialArgs = rec {
            inherit
              inputs
              hostname
              home-manager
              pkgs-unstable
              ;
            xelib = import ./xelib pkgs;
            host = xelib.hosts.${hostname};
            xelpkgs = import ./pkgs pkgs;
            isNixOS = (builtins.elemAt system 1);
          };
        };

      mkNixosConfiguration =
        hostname:
        let
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};
          xelib = import ./xelib pkgs;

          extras = {
            inherit inputs hostname xelib;
            xelpkgs = import ./pkgs pkgs;
            pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
            host = xelib.hosts.${hostname};
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [
            catppuccin.nixosModules.catppuccin
            ./nixos/${hostname}.nix

            headplane.nixosModules.headplane
            { nixpkgs.overlays = [ headplane.overlays.default ]; }

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit home-manager;
                isNixOS = true;
              }
              // extras;
              home-manager.sharedModules = home-manager-modules;
              home-manager.users.root = import ./home/common;
              home-manager.users.${extras.host.username} = import ./home/${hostname}.nix;
            }
          ];
          specialArgs = extras;
        };
    in
    {
      homeConfigurations = {
        # non-nixos
        macintosh = mkHomeConfiguration "x86_64-darwin" "macintosh";
      };

      nixosConfigurations = {
        flynn = mkNixosConfiguration "flynn";
        pete = mkNixosConfiguration "pete";

        hyzenberg = mkNixosConfiguration "hyzenberg";
        ehrman = mkNixosConfiguration "ehrman";
        huell = mkNixosConfiguration "huell";
      };
    };
}
