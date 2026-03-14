# an older version of `bind` that supports DNSSEC
# github.com/NixOS/nixpkgs/issues/169442
# https://github.com/NixOS/nixpkgs/blob/4cfcbac24a1e0e57a6a5af28e12438137b93214c/pkgs/servers/dns/bind/default.nix
{ pkgs, ... }: pkgs.callPackage ./pkg.nix { }
