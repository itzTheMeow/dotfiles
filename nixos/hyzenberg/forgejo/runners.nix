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
      services.forgejo-runner.instances.${runner.id} = {
        enable = true;
        settings = {
          runner.labels = runner.labels;
          server.connections.default = {
            url = xelib.apps.forgejo.url;
            uuid = runner.id;

          };
        };
        secrets.server.connections.default.token_url =
          config.sops.secrets."forgejo-runner-${runner.id}".path;
      };

      sops.secrets."forgejo-runner-${runner.id}" = {
        sopsFile = config.sops.opSecrets.forgejo-runners.fullPath;
        key = runner.id;
      };
      sops.opSecrets.forgejo-runners.keys.${runner.id} =
        "op://Private/yjdttmakvgkuiia5xhda2pl3ve/Actions Runners/${runner.id}";
    })
    [
      {
        id = "84e66c7d-7f52-4c56-a460-6ecafb6c40d2";
        labels = [
          "nix:docker://nixos/nix"
          "node:docker://node:20"
        ];
      }
    ]
)
