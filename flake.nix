{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    opinject.url = "github:itzTheMeow/opinject";
    #opnix.url = "github:itzTheMeow/opnix/a18b32d338d2316f12afe8c694525f1ef5b01c75";
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

      # Shared Home Manager module configuration
      mkHomeModules = hostname: [
        catppuccin.homeModules.catppuccin
        plasma-manager.homeModules.plasma-manager
        opinject.homeManagerModules.default
        ./home/${hostname}.nix
      ];

      # Shared Home Manager extraSpecialArgs
      mkHomeSpecialArgs = hostname: isNixOS: {
        inherit
          inputs
          hostname
          home-manager
          isNixOS
          ;
        utils = import ./lib/utils.nix;
      };

      # Standalone Home Manager configuration
      mkHomeConfiguration =
        system: hostname:
        home-manager.lib.homeManagerConfiguration {
          pkgs = builtins.getAttr (system [ 0 ]) nixpkgs.legacyPackages;

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
          ++ mkHomeModules hostname;

          extraSpecialArgs = mkHomeSpecialArgs hostname (system [ 1 ]);
        };

      # NixOS configuration with integrated Home Manager
      mkNixosConfiguration =
        hostname: username:
        nixpkgs.lib.nixosSystem {
          modules = [
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${username} = {
                  imports = mkHomeModules hostname;
                };
                extraSpecialArgs = mkHomeSpecialArgs hostname true;
              };
            }
            ./nixos/${hostname}.nix
          ];
          specialArgs = {
            inherit inputs hostname username;
            utilslib = import ./lib/utils.nix;
          };
        };
    in
    {
      homeConfigurations = {
        laptop = mkHomeConfiguration nixos "laptop";

        hyzenberg = mkHomeConfiguration linux "hyzenberg";
        netrohost = mkHomeConfiguration linux "netrohost";

        macintosh = mkHomeConfiguration darwin "macintosh";
      };

      nixosConfigurations = {
        laptop = mkNixosConfiguration "laptop" "xela";
      };
    };
}
