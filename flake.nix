{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
      opinject,
      plasma-manager,
      ...
    }@inputs:
    let
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
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${builtins.elemAt system 0};

          modules = [
            {
              nixpkgs.config.allowUnfree = true;

              # fix fish on macos
              nixpkgs.overlays = [
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

          extraSpecialArgs = {
            inherit
              inputs
              hostname
              home-manager
              ;
            isNixOS = (builtins.elemAt system 1);

            globals = import ./lib/globals.nix;
            utils = import ./lib/utils.nix nixpkgs.lib;
          };
        };

      mkNixosConfiguration =
        hostname: username:
        nixpkgs.lib.nixosSystem {
          system = builtins.elemAt nixos 0;
          modules = [
            catppuccin.nixosModules.catppuccin
            ./nixos/${hostname}.nix
          ];
          specialArgs = {
            inherit inputs hostname username;

            globals = import ./lib/globals.nix;
            utilslib = import ./lib/utils.nix nixpkgs.lib;
          };
        };
    in
    {
      homeConfigurations = {
        laptop = mkHomeConfiguration nixos "laptop";
        tv = mkHomeConfiguration nixos "tv";

        hyzenberg = mkHomeConfiguration linux "hyzenberg";
        netrohost = mkHomeConfiguration linux "netrohost";

        macintosh = mkHomeConfiguration darwin "macintosh";
      };

      nixosConfigurations = {
        laptop = mkNixosConfiguration "laptop" "xela";
        tv = mkNixosConfiguration "tv" "tv";
      };
    };
}
