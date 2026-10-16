{
  config,
  host,
  lib,
  xelib,
  ...
}:
let
  gitSecrets = {
    sops.groups.git_ssh = {
      github_auth = {
        value = "op://Private/royxpwncznclgwwbtp5gq4syle/public key";
        owner = host.username;
      };
      github_signing = {
        value = "op://Private/brpzxia4pb2uk7ujbyf3nj7qci/public key";
        owner = host.username;
      };
      # scoped read-only deploy key for nvstly dotfiles repo
      nvstly_deploy = {
        value = "op://NVSTly/yrzxyhogbfzbaasgginj4j6ria/private key";
        owner = host.username;
      };
    }
    // lib.optionalAttrs (xelib.apps ? forgejo) {
      forgejo = {
        value = "op://Private/hgsv724d4jvdaqfljg664v62aq/public key";
        owner = host.username;
      };
    };
  };

  codeHosts = {
    "github.com" = [
      config.sops.groupPaths.git_ssh.github_auth
      config.sops.groupPaths.git_ssh.github_signing
    ];
  }
  // lib.optionalAttrs (xelib.apps ? forgejo) {
    ${xelib.apps.forgejo.domain} = [
      config.sops.groupPaths.git_ssh.forgejo
      config.sops.groupPaths.git_ssh.github_signing
    ];
  };

  codeHostNames = builtins.attrNames codeHosts;
in
{
  config = lib.mkMerge [
    gitSecrets
    {
      # system-wide so both user and root (nix daemon) git fetches can resolve the repo URL
      programs.ssh.extraConfig = ''
        Host nvstly-dotfiles
          HostName github.com
          User git
          HostKeyAlias github.com
          IdentityFile ${config.sops.groupPaths.git_ssh.nvstly_deploy}
          IdentitiesOnly yes
          StrictHostKeyChecking accept-new
      '';

      home-manager.importUser = [
        (_: {
          programs.git = {
            enable = true;
            settings = {
              user = {
                name = "Meow";
                email = "github@${xelib.domain}";
              };

              pull.rebase = false;
              init.defaultBranch = "master";
            };
          };
        })
        (hm: {
          programs.ssh.settings = lib.optionalAttrs xelib.isDesktop (
            lib.genAttrs codeHostNames (
              domain:
              hm.lib.hm.dag.entryBefore [ "*" ] {
                IdentityFile = codeHosts.${domain};
                IdentitiesOnly = true;
              }
            )
          );
        })
      ];
    }
  ];
}
