{
  description = "My nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-bind916.url = "github:nixos/nixpkgs/4cfcbac24a1e0e57a6a5af28e12438137b93214c";
    flake-utils.url = "github:numtide/flake-utils";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:itzTheMeow/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "";
      inputs.home-manager.follows = "";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dns = {
      # https://github.com/nix-community/dns.nix/pull/52
      url = "github:felixalbrigtsen/dns.nix/f5a60ede524ee641256f878b1f28d4151577a727";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # my stuff
    timefinder-electron = {
      url = "git+https://forge.xela.codes/xela/timefinder-electron.git";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
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
      home-manager,
      nixpkgs-unstable,
      nixpkgs,
      plasma-manager,
      self,
      sops-nix,
      ...
    }@inputs:
    let
      nixpkgs_args = system: {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          # overlays from inputs
          inputs.timefinder-electron.overlays.default
        ]
        # custom overlays
        ++ (map (file: import ./overlays/${file}) (builtins.attrNames (builtins.readDir ./overlays)));
      };

      home-manager-modules = [
        catppuccin.homeModules.catppuccin
        plasma-manager.homeModules.plasma-manager
        sops-nix.homeManagerModules.sops
        (import ./xelib/opsecrets.nix).homeManagerModule
      ];

      mkNixosConfiguration =
        system: hostname:
        let
          #TODO:26.11 pete has to use custom bigscreen branch
          nixpkgs = if hostname == "pete" then inputs.nixpkgs-unstable else inputs.nixpkgs;

          pkgs = import nixpkgs (nixpkgs_args system);
          pkgs-unstable = import nixpkgs-unstable (nixpkgs_args system);
          xelpkgs = import ./pkgs { inherit pkgs pkgs-unstable; };

          extras = {
            inherit
              dns
              home-manager
              hostname
              inputs
              pkgs-unstable
              self
              system
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
            # custom nixpkgs instance with overlays/config
            { nixpkgs.pkgs = pkgs; }

            # sops
            sops-nix.nixosModules.sops
            (import ./xelib/opsecrets.nix).nixosModule

            # misc
            catppuccin.nixosModules.catppuccin
            inputs.impermanence.nixosModules.impermanence

            # main config
            (import ./nixos hostname)

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
          ]
          ++ map (file: ./modules/${file}) (builtins.attrNames (builtins.readDir ./modules));
          specialArgs = extras // {
            inherit xelib;
          };
        };

      # hosts with x86_64-linux
      x86Hosts = [
        "flynn"
        "pete"
        "hyzenberg"
        "ehrman"
        "huell"
      ];
      allHosts = x86Hosts;
    in
    {
      homeConfigurations = {
        # non-nixos
        #macintosh = mkHomeConfiguration "x86_64-darwin" "macintosh";
      };

      nixosConfigurations = nixpkgs.lib.genAttrs x86Hosts (
        name: mkNixosConfiguration "x86_64-linux" name
      );
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs (nixpkgs_args system);
        lib = pkgs.lib;

        formatScript = pkgs.writeShellApplication {
          name = "format";
          runtimeInputs = with pkgs; [
            findutils
            nixfmt
            go
            prettier
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

        # maps all *.package.nix files to their directory name
        # appends the * part if it exists
        hostPackages =
          hostDir:
          let
            findPackages =
              dir: relParts:
              lib.pipe (builtins.readDir dir) [
                (lib.mapAttrsToList (
                  name: type:
                  let
                    path = dir + "/${name}";
                  in
                  if type == "directory" then
                    findPackages path (relParts ++ [ name ])
                  else if type == "regular" && lib.hasSuffix "package.nix" name then
                    let
                      prefix = lib.removeSuffix "." (lib.removeSuffix "package.nix" name);
                      attrName = lib.concatStringsSep "-" (relParts ++ lib.optional (prefix != "") prefix);
                    in
                    [ (lib.nameValuePair attrName (pkgs.callPackage path { })) ]
                  else
                    [ ]
                ))
                lib.flatten
              ];
          in
          builtins.listToAttrs (findPackages hostDir [ ]);

        allPackages = lib.mergeAttrsList (
          map (host: hostPackages (./nixos + "/${host}")) (allHosts ++ [ "_features" ])
        );
      in
      {
        packages = allPackages;

        apps.format = {
          type = "app";
          program = "${formatScript}/bin/format";
        };
      }
    );
}
