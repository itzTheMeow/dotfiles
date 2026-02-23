{ host, pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "sops-build-secrets";
      runtimeInputs = with pkgs; [
        jq
        sops
        ssh-to-age
      ];
      text = ''
        # Export the public key for encryption.
        export PUBLIC_KEY_URI="${host.hostPublicKey}"

        # Determine the best 1Password CLI command.
        if [ -x "/usr/local/bin/op" ]; then
          export OP_CMD="/usr/local/bin/op"
        elif [ -x "/run/wrappers/bin/op" ]; then
          export OP_CMD="/run/wrappers/bin/op"
        else
          export OP_CMD="${pkgs._1password-cli}/bin/op"
        fi

        ${pkgs.bash}/bin/bash ${../../scripts/sops.sh}
      '';
    })
  ];
}
