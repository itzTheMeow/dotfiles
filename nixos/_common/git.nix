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
      home-manager.importUser = [
        (hm: {
          programs.ssh.settings = lib.genAttrs codeHostNames (
            domain:
            hm.lib.hm.dag.entryBefore [ "*" ] {
              IdentityFile = codeHosts.${domain};
              IdentitiesOnly = true;
            }
          );
        })
      ];
    }
  ];
}
