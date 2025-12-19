{ hostname, ... }:
{
  system.stateVersion = "25.11";

  imports = [
    ../${hostname}-hardware-configuration.nix
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
}
