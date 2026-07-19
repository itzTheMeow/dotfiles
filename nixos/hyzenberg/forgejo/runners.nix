{
  config,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  runner-image = pkgs.dockerTools.buildImage {
    name = "nix-forgejo-runner";
    tag = "latest";

    copyToRoot = pkgs.buildEnv {
      name = "forgejo-runner-env";
      paths = with pkgs; [
        nix
        nodejs
        git
        bash
        coreutils
        busybox
        cacert
        # copied from here: https://github.com/cachix/install-nix-action/blob/23cf0fec1d55e0b1f2631aedd2a610c21ef8b077/install-nix.sh
        (pkgs.writeTextDir "etc/nix/nix.conf" ''
          show-trace = true
          max-jobs = auto
          ssl-cert-file = ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          trusted-users = root
          experimental-features = nix-command flakes
          always-allow-substitutes = true
          build-users-group =
        '')
      ];
      pathsToLink = [
        "/bin"
        "/etc"
        "/share"
      ];
    };

    config = {
      Env = [
        "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  };
in
lib.mkMerge (
  (
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
          secrets.server.connections.default.token_url = config.sops.groupPaths.forgejo."runner-${runner.id}";
        };

        systemd.services."forgejo-runner-${runner.id}".after = [ "forgejo-load-runner-images.service" ];
        sops.groups.forgejo."runner-${runner.id}" =
          "op://Private/yjdttmakvgkuiia5xhda2pl3ve/Actions Runners/${runner.id}";
      })
      [
        {
          id = "84e66c7d-7f52-4c56-a460-6ecafb6c40d2";
          labels = [
            "nix:docker://nix-forgejo-runner"
          ];
        }
      ]
  )
  ++ [
    {
      systemd.services.forgejo-load-runner-images = {
        description = "Load forgejo-runner Docker images";
        after = [ "docker.service" ];
        wants = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.docker}/bin/docker load -i ${runner-image}";
        };
      };
    }
  ]
)
