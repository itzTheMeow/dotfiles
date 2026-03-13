{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:itzTheMeow/home-manager/pegasus-frontend";
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
    dns = {
      url = "github:kirelagin/dns.nix";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    headplane = {
      url = "github:tale/headplane";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://xelacodes.cachix.org"
    ];
    extra-trusted-public-keys = [
      "xelacodes.cachix.org-1:mlXOAvMV//6WvlZAv0xu8fBflpDZTOo9n4mU9W7XxyU="
    ];
  };

  outputs =
    {
      catppuccin,
      dns,
      flake-utils,
      headplane,
      home-manager,
      nixpkgs-unstable,
      nixpkgs,
      plasma-manager,
      self,
      sops-nix,
      ...
    }@inputs:
    let
      home-manager-modules = [
        catppuccin.homeModules.catppuccin
        plasma-manager.homeModules.plasma-manager
        sops-nix.homeManagerModules.sops
        (import ./xelib/opsecrets.nix).homeManagerModule
      ];

      mkHomeConfiguration =
        system: hostname:
        home-manager.lib.homeManagerConfiguration rec {
          pkgs = import nixpkgs {
            inherit system;
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
              self
              ;
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            xelpkgs = import ./pkgs { inherit pkgs pkgs-unstable; };
            xelib = import ./xelib {
              inherit
                pkgs
                pkgs-unstable
                self
                xelpkgs
                ;
            };
            host = xelib.hosts.${hostname};
          };
        };

      mkNixosConfiguration =
        system: hostname:
        let
          # pete has to use unstable for bigscreen
          nixpkgs = if hostname == "pete" then nixpkgs-unstable else inputs.nixpkgs;

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          xelpkgs = import ./pkgs { inherit pkgs pkgs-unstable; };

          extras = {
            inherit
              dns
              home-manager
              hostname
              inputs
              pkgs-unstable
              self
              xelib
              xelpkgs
              ;
            host = xelib.hosts.${hostname};
          };

          xelib = import ./xelib (
            extras
            // {
              inherit pkgs;
            }
          );
        in
        nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [
            # sops
            sops-nix.nixosModules.sops
            (import ./xelib/opsecrets.nix).nixosModule

            # headplane
            headplane.nixosModules.headplane
            { nixpkgs.overlays = [ headplane.overlays.default ]; }

            # misc
            catppuccin.nixosModules.catppuccin
            ./xelib/dnszones.nix

            # main config
            ./nixos/${hostname}.nix

            # home-manager
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extras // {
                inherit xelib;
              };
              home-manager.sharedModules = home-manager-modules;
              home-manager.users.root = import ./home/common;
              home-manager.users.${extras.host.username} = import ./home/${hostname}.nix;
            }
          ];
          specialArgs = extras // {
            inherit xelib;
          };
        };
    in
    {
      homeConfigurations = {
        # non-nixos
        macintosh = mkHomeConfiguration "x86_64-darwin" "macintosh";
      };

      nixosConfigurations = {
        flynn = mkNixosConfiguration "x86_64-linux" "flynn";
        pete = mkNixosConfiguration "x86_64-linux" "pete";

        hyzenberg = mkNixosConfiguration "x86_64-linux" "hyzenberg";
        ehrman = mkNixosConfiguration "x86_64-linux" "ehrman";
        huell = mkNixosConfiguration "x86_64-linux" "huell";
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        formatScript = pkgs.writeShellApplication {
          name = "format";
          runtimeInputs = with pkgs; [
            nixfmt
            go
            nodePackages.prettier
          ];
          text = ''
            echo "Formatting Nix..."
            find . -name "*.nix" -exec nixfmt {} +
            echo "Formatting Go..."
            gofmt -w ./go
            echo "Formatting Prettier..."
            prettier --write .
          '';
        };
      in
      {
        apps.format = {
          type = "app";
          program = "${formatScript}/bin/format";
        };
      }
    );
}
