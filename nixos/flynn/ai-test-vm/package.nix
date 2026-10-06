# Flake package flynn-ai-test-vm, so the VM can be built and exercised without a
# system rebuild:
#   nix build .#flynn-ai-test-vm
#   ./result/bin/ai-test-vm provision
{ pkgs, ... }:
let
  # flynn is the only host this lives on, and the username is the only thing
  # the guest has to agree on with the host
  username = "xela";
in
(import ./vm.nix { inherit pkgs username; }).script
