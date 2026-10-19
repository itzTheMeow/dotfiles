# stage 1: the tracked packages of ONE host - run one process per host so
# memory stays bounded (a full-fleet eval OOMs small machines), with:
#   nix eval --impure --json --expr \
#     'import ./derived.nix { dir = "/path/to/flake"; host = "flynn"; }'
{
  dir,
  host,
}:
let
  config = (builtins.getFlake dir).nixosConfigurations.${host}.config;
in
{
  inherit host;
  system = config.nixpkgs.system;
  derived = config.trackPackages.derived or [ ];
}
