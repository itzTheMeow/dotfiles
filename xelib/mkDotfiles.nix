/*
  Shared dotfiles factory.

  Builds the full outputs of a dotfiles-style flake. This repo calls it with
  its own defaults; satellite repos (nvstly) add this repo as a
  flake input and call it with their own `nixosDir`/hosts data, reusing
  everything else (modules, overlays, pkgs, xelib, common, types, features).
*/
{
  self,
  inputs,
  nixConfig,
  nixosDir,
  hosts,
  trustedHosts,
  # hosts/apps from satellite repos, consumed by ssh + headscale here
  externalHosts ? { },
  externalApps ? { },
  externalRecords ? [ ],
  # static per-host app declarations injected into `config.apps`
  apps ? { },
  # null = only the shared home/common config is used
  homeDir ? ./../home,
  # machine-local skip-worktree overrides; null = none
  localDir ? ./../local,
  # hosts that build against nixpkgs-unstable
  unstableHosts ? [ ],
  # whether to set up the impure nixpkgs-overlays NIX_PATH machinery.
  # satellite hosts can't use it since `overlays/` lives in this repo.
  impureOverlays ? true,
}:
let
  inherit (inputs.nixpkgs) lib;

  # parse the attic settings from the nixConfig
  # this'll need changed if the URLs ever change shape
  atticFrom =
    url: publicKey:
    let
      match = builtins.match "https://([^/]+)/?(.+)" url;
    in
    {
      domain = builtins.elemAt match 0;
      cacheName = builtins.elemAt match 1;
      inherit publicKey;
    };

  # every substituter from the nixConfig, in order
  attics =
    lib.zipListsWith atticFrom nixConfig.extra-substituters
      nixConfig.extra-trusted-public-keys;
  # the primary cache - the one CI pushes to
  attic = builtins.head attics;

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
        unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      })
    ]
    # custom overlays
    ++ (map (file: import ./../overlays/${file}) (builtins.attrNames (builtins.readDir ./../overlays)));
  };

  home-manager-modules = [
    inputs.catppuccin.homeModules.catppuccin
    inputs.plasma-manager.homeModules.plasma-manager
    inputs.sops-nix.homeManagerModules.sops
    (import ./opsecrets.nix).homeManagerModule
  ];

  # hosts with configs to build: directories in nixosDir that aren't internal
  buildableHosts =
    let
      entries = builtins.readDir nixosDir;
    in
    builtins.filter (name: entries.${name} == "directory" && !lib.strings.hasPrefix "_" name) (
      builtins.attrNames entries
    );

  mkNixosConfiguration =
    system: hostname:
    let
      nixpkgs = if lib.elem hostname unstableHosts then inputs.nixpkgs-unstable else inputs.nixpkgs;

      pkgs = import nixpkgs (nixpkgs_args system);

      extras = {
        inherit
          attic
          attics
          externalApps
          externalHosts
          externalRecords
          hostname
          hosts
          impureOverlays
          inputs
          localDir
          self
          system
          trustedHosts
          xelib
          ;
        inherit (inputs) dns home-manager;
        host = xelib.hosts.${hostname};
      };

      xelib =
        (import ./default.nix (extras // { inherit pkgs; }))
        # tack on umport library
        // {
          umport = inputs.nypkgs.lib.${system}.umport;
        };

      # modules/*.hm.nix are home-manager sharedModules, the rest are NixOS modules
      moduleFiles = xelib.umport { path = ./../modules; };
      hmModuleFile = file: lib.hasSuffix ".hm.nix" (toString file);
      nixosModules = builtins.filter (file: !hmModuleFile file) moduleFiles;
      hmModules = builtins.filter hmModuleFile moduleFiles;

      hostDir = nixosDir + "/${hostname}";
      hostEntries = builtins.readDir hostDir;

      # prefer a caller-local feature dir, falling back to this repo's shared ones
      featurePath =
        feature:
        if builtins.pathExists (nixosDir + "/_features/${feature}") then
          nixosDir + "/_features/${feature}"
        else
          ./../nixos/_features/${feature};

      hostImports =
        # local machine-specific overrides - a committed stub (skip-worktree
        # hides local edits); imported unconditionally since pure-eval
        # pathExists cant see untracked files
        lib.optionals (localDir != null) [ (localDir + "/nixos.nix") ]
        # shared common config
        ++ [ ./../nixos/common.nix ]
        # import all .nix files in the host directory
        ++ map (name: hostDir + "/${name}") (
          builtins.filter (
            name:
            # import directories
            hostEntries.${name} == "directory"
            || (
              # or .nix files
              hostEntries.${name} == "regular"
              && builtins.match ".*\\.nix" name != null
              # ignore features file as that is imported later
              && name != "features.nix"
            )
          ) (builtins.attrNames hostEntries)
        )
        # import all enabled features
        ++ map featurePath (import (hostDir + "/features.nix"));
    in
    nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        # custom nixpkgs instance with overlays/config
        { nixpkgs.pkgs = pkgs; }

        # sops
        inputs.sops-nix.nixosModules.sops
        (import ./opsecrets.nix).nixosModule

        # misc
        inputs.catppuccin.nixosModules.catppuccin
        inputs.copyparty.nixosModules.default
        inputs.degoog.nixosModules.default
        inputs.impermanence.nixosModules.impermanence
        inputs.vscode-server-fix.nixosModules.default
      ]
      # custom forgejo-runner module from unstable (stable doesn't have it yet)
      # TODO:26.11 remove this import once the upstream module reaches stable
      ++ nixpkgs.lib.optionals (!lib.elem hostname unstableHosts) [
        (inputs.nixpkgs-unstable + "/nixos/modules/services/continuous-integration/forgejo-runner.nix")
      ]
      ++ [
        # main config
        { imports = hostImports; }

        # static app declarations (from satellite repos)
        (lib.optionalAttrs (apps ? ${hostname}) {
          apps = lib.mkDefault apps.${hostname};
        })

        # home-manager
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = extras // {
            inherit xelib;
          };
          home-manager.sharedModules = home-manager-modules ++ hmModules;
          home-manager.users.root = ./../home/common;
          home-manager.users.${extras.host.username} =
            if homeDir == null then ./../home/common else homeDir + "/${hostname}.nix";
        }
      ]
      ++ nixosModules;
      specialArgs = extras // {
        inherit xelib;
      };
    };

  perSystem =
    system:
    let
      pkgs = import inputs.nixpkgs (nixpkgs_args system);
      lib = pkgs.lib;

      # treefmt wrapper + formatting check, configured by the repo's treefmt.nix
      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./../treefmt.nix;

      # maps all *.package.nix files to their directory name
      # appends the * part if it exists
      hostPackages =
        hostDir:
        let
          findPackages =
            dir: relParts:
            let
              entries = builtins.readDir dir;
            in
            lib.pipe (builtins.attrNames entries) [
              (map (
                name:
                let
                  path = dir + "/${name}";
                in
                if entries.${name} == "directory" then
                  findPackages path (relParts ++ [ name ])
                else if entries.${name} == "regular" && lib.hasSuffix "package.nix" name then
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
        map (host: hostPackages (nixosDir + "/${host}")) (
          buildableHosts ++ lib.optionals (builtins.pathExists (nixosDir + "/_features")) [ "_features" ]
        )
      );
    in
    {
      packages = allPackages;

      # for `nix fmt`
      formatter = treefmtEval.config.build.wrapper;
      # for `nix flake check` - fails if anything is unformatted
      checks.formatting = treefmtEval.config.build.check self;
    };
in
{
  # re-export the raw inputs so satellite repos can pass them back in
  flakeInputs = inputs;

  # shared host/trust data for satellite repos to build on
  inherit hosts trustedHosts;

  # primary attic cache (first substituter) - re-exported for CI
  inherit attic;

  nixosConfigurations = lib.genAttrs buildableHosts (mkNixosConfiguration "x86_64-linux");

  homeConfigurations = { };
}
// inputs.flake-utils.lib.eachDefaultSystem perSystem
