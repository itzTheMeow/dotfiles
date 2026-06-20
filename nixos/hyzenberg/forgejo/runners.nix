{
  config,
  lib,
  pkgs,
  xelib,
  ...
}:
lib.mkMerge (
  (
    # map runners to instances
    map
      (runner: {
        services.gitea-actions-runner.instances.${runner.name} = {
          enable = true;
          name = runner.name;
          url = xelib.apps.forgejo.url;
          tokenFile = config.sops.secrets."forgejo-runner-${runner.name}".path;
        }
        // runner.options;

        sops.envFiles."forgejo-runner-${runner.name}".TOKEN =
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
  ++ [
    {
      services.gitea-actions-runner.package = pkgs.forgejo-runner;
    }
  ]
)
