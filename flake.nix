rec {
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
    copyparty = {
      url = "github:9001/copyparty";
      inputs.flake-utils.follows = "flake-utils";
    };
    dns = {
      url = "github:nix-community/dns.nix";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nypkgs = {
      url = "github:yunfachi/nypkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server-fix = {
      url = "github:nix-community/nixos-vscode-server";
    };

    # my stuff
    dotfiles-media = {
      url = "git+https://forge.xela.codes/xela/dotfiles-media.git";
      flake = false;
    };
    timefinder-electron = {
      url = "git+https://forge.xela.codes/xela/timefinder-electron.git";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # this HAS to be static so its the source of truth for the atticd config
  nixConfig = {
    extra-substituters = [ "https://attic.xela.codes/xela-master" ];
    extra-trusted-public-keys = [ "xela-master:Ul5iGYi/rWkh/IOZTxGvRi7AjiGAvCbYs68mcm3Al1w=" ];
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
      # parse the attic settings from the nixConfig
      # this'll need changed if we ever have more than one substituter
      attic =
        let
          match = builtins.match "https://([^/]+)/?(.+)" (builtins.head nixConfig.extra-substituters);
        in
        {
          domain = builtins.elemAt match 0;
          cacheName = builtins.elemAt match 1;
          publicKey = builtins.head nixConfig.extra-trusted-public-keys;
        };

      nixpkgs_args = system: {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          # overlays from inputs
          inputs.copyparty.overlays.default
          inputs.nix-vscode-extensions.overlays.default
          inputs.timefinder-electron.overlays.default
          # expose nixpkgs-unstable so overlays can use `final.unstable`
          (final: prev: {
            unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          })
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
              attic
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

          xelib =
            (import ./xelib (extras // { inherit pkgs; }))
            # tack on umport library
            // {
              umport = inputs.nypkgs.lib.${system}.umport;
            };
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
            inputs.copyparty.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            inputs.vscode-server-fix.nixosModules.default
          ]
          # custom forgejo-runner module from unstable (stable doesn't have it yet)
          # TODO:26.11 remove this import once the upstream module reaches stable
          ++ nixpkgs.lib.optionals (hostname != "pete") [
            (nixpkgs-unstable + "/nixos/modules/services/continuous-integration/forgejo-runner.nix")
          ]
          ++ [
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
          ++ xelib.umport { path = ./modules; };
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
      # re-export for CI
      inherit attic;

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
