{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "sops-build-secrets";
      runtimeInputs = with pkgs; [
        jq
        sops
        ssh-to-age
      ];
      text = builtins.readFile ../../scripts/sops.sh;
    })
  ];
}
