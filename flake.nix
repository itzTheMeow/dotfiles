{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
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
      sops-nix,
      ...
    }@inputs:
    let
      home-manager-modules = [
        catppuccin.homeModules.catppuccin
        plasma-manager.homeModules.plasma-manager
        opinject.homeManagerModules.default
        sops-nix.homeManagerModules.sops
      ];

      mkHomeConfiguration =
        system: hostname:
        home-manager.lib.homeManagerConfiguration rec {
          pkgs = import nixpkgs {
            system = builtins.elemAt system 0;
            config.allowUnfree = true;
            overlays = [
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
          };

          modules = home-manager-modules ++ [ ./home/${hostname}.nix ];

          extraSpecialArgs = rec {
            inherit
              inputs
              hostname
              home-manager
              ;
            pkgs-unstable = import nixpkgs-unstable {
              system = builtins.elemAt system 0;
              config.allowUnfree = true;
            };
            xelib = import ./xelib pkgs;
            host = xelib.hosts.${hostname};
            xelpkgs = import ./pkgs { inherit pkgs pkgs-unstable; };
            isNixOS = (builtins.elemAt system 1);
          };
        };

      mkNixosConfiguration =
        hostname:
        let
          system = "x86_64-linux";
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          xelib = import ./xelib pkgs;

          extras = {
            inherit
              inputs
              hostname
              xelib
              pkgs-unstable
              ;
            xelpkgs = import ./pkgs { inherit pkgs pkgs-unstable; };
            host = xelib.hosts.${hostname};
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [
            # sops
            sops-nix.nixosModules.sops
            ./xelib/opsecrets.nix

            # headplane
            headplane.nixosModules.headplane
            { nixpkgs.overlays = [ headplane.overlays.default ]; }

            # misc
            catppuccin.nixosModules.catppuccin

            # main config
            ./nixos/${hostname}.nix

            # home-manager
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
