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
              ;

            pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
            _npkgs = nixpkgs.legacyPackages.${system};
            xelib = import ./xelib _npkgs;
            host = xelib.hosts.${hostname};
            xelpkgs = import ./pkgs _npkgs;
          };
        };
    in
    {
      homeConfigurations = {
        flynn = mkHomeConfiguration nixos "flynn";
        pete = mkHomeConfiguration nixos "pete";

        hyzenberg = mkHomeConfiguration nixos "hyzenberg";
        ehrman = mkHomeConfiguration nixos "ehrman";

        # non-nixos
        netrohost = mkHomeConfiguration linux "netrohost";
        macintosh = mkHomeConfiguration darwin "macintosh";
      };

      nixosConfigurations = {
        flynn = mkNixosConfiguration "flynn";
        pete = mkNixosConfiguration "pete";

        hyzenberg = mkNixosConfiguration "hyzenberg";
        ehrman = mkNixosConfiguration "ehrman";
      };
    };
}
