{
  config,
  lib,
  xelib,
  ...
}:
lib.mkMerge (
  # map runners to instances
  map
    (runner: {
      services.gitea-actions-runner.instances.${runner.name} = {
        enable = true;
        name = runner.name;
        url = xelib.apps.forgejo.url;
        tokenFile = config.sops.secrets."forgejo-runner-${runner.name}";
      }
      // runner.options;

      sops.secrets."forgejo-runner-${runner.name}" = {
        sopsFile = config.sops.opSecrets.forgejo-runners.fullPath;
        key = runner.name;
      };
      sops.opSecrets.forgejo-runners.keys.${runner.name} =
        "op://Private/yjdttmakvgkuiia5xhda2pl3ve/Actions Runners/${runner.name}";
    })
    [
      {
        name = "xela-runner";
        options = {
          labels = [
            "nix:docker://nixos/nix"
          ];
        };
      }
    ]
)
