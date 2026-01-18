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

      # extra global modules to enable
      xelib = import ./xelib nixpkgs.lib;

      mkHomeConfiguration =
        system: hostname:
        home-manager.lib.homeManagerConfiguration rec {
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
            xelib = import ./xelib pkgs;
            xelpkgs = import ./pkgs pkgs;
            isNixOS = (builtins.elemAt system 1);
          };
        };

      mkNixosConfiguration =
        hostname: username:
        nixpkgs.lib.nixosSystem rec {
          system = builtins.elemAt nixos 0;

          modules = [
            catppuccin.nixosModules.catppuccin
            ./nixos/${hostname}.nix
          ];
          specialArgs = rec {
            inherit
              inputs
              hostname
              username
              ;

            _npkgs = nixpkgs.legacyPackages.${system};
            xelib = import ./xelib _npkgs;
            xelpkgs = import ./pkgs _npkgs;
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
