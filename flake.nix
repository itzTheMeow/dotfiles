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
  };

  outputs =
    {
      catppuccin,
      home-manager,
      nixpkgs,
      nixpkgs-unstable,
      opinject,
      plasma-manager,
      ...
    }@inputs:
    let
      # OS types
      nixos = [
        "x86_64-linux"
        true
      ];
      linux = [
        "x86_64-linux"
        false
      ];
      darwin = [
        "x86_64-darwin"
        false
      ];

      mkHomeConfiguration =
        system: hostname:
        let
          pkgs-unstable = nixpkgs-unstable.legacyPackages.${builtins.elemAt system 0};
        in
        home-manager.lib.homeManagerConfiguration rec {
          pkgs = nixpkgs.legacyPackages.${builtins.elemAt system 0};

          modules = [
            {
              nixpkgs.config.allowUnfree = true;

              nixpkgs.overlays = [
                # fix fish on macos
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
            }
          ]
          ++ [
            catppuccin.homeModules.catppuccin
            plasma-manager.homeModules.plasma-manager
            opinject.homeManagerModules.default
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
          system = builtins.elemAt nixos 0;
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

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit home-manager;
                isNixOS = true;
              }
              // extras;
              home-manager.sharedModules = [
                catppuccin.homeModules.catppuccin
                plasma-manager.homeModules.plasma-manager
                opinject.homeManagerModules.default
              ];
              home-manager.users.${extras.host.username} = import ./home/${hostname}.nix;
            }
          ];
          specialArgs = extras;
        };
    in
    {
      homeConfigurations = {
        # non-nixos
        macintosh = mkHomeConfiguration darwin "macintosh";
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
