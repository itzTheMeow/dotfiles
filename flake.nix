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
      url = "github:itzTheMeow/home-manager/pegasus-frontend";
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
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
    degoog = {
      url = "github:degoog-org/degoog";
      inputs.nixpkgs.follows = "nixpkgs";
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
    timefinder-electron = {
      url = "git+https://forge.xela.codes/xela/timefinder-electron.git";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # external nvstly repo that we read config from
    nvstly = {
      url = "git+ssh://nvstly-dotfiles/nvstly/dotfiles.git";
      flake = false;
    };
  };

  # this HAS to be static for the flake, so its the source of truth for the atticd config
  nixConfig = {
    extra-substituters = [ "https://attic.xela.codes/xela-master" ];
    extra-trusted-public-keys = [ "xela-master:Ul5iGYi/rWkh/IOZTxGvRi7AjiGAvCbYs68mcm3Al1w=" ];
  };

  outputs =
    { self, ... }@inputs:
    let
      nvstlyHosts = import (inputs.nvstly + "/hosts.nix");
      nvstlyApps = import (inputs.nvstly + "/apps.nix");
    in
    {
      # shared factory for other repos to consume
      lib.mkEntrypoint = import ./entrypoint.nix;

      # re-exports for other repos
      flakeInputs = inputs;
      hostsTable = import ./xelib/hosts.nix;
    }
    # actual dotfiles config
    // (import ./entrypoint.nix {
      inherit self inputs nixConfig;
      nixosDir = ./nixos;
      hosts = (import ./xelib/hosts.nix).hosts // nvstlyHosts.hosts;
      trustedHosts = (import ./xelib/hosts.nix).trustedHosts;
      externalHosts = nvstlyHosts.hosts;
      externalApps = nvstlyApps.hosts;
      externalRecords = nvstlyApps.extraRecords or [ ];
      unstableHosts = [ "pete" ];
    });
}
