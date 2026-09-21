{
  config,
  host,
  lib,
  xelib,
  ...
}:
let
  gitSecrets = {
    sops.opSecrets.git_ssh = {
      keys = {
        github_auth = "op://Private/royxpwncznclgwwbtp5gq4syle/public key";
        github_signing = "op://Private/brpzxia4pb2uk7ujbyf3nj7qci/public key";
        forgejo = "op://Private/hgsv724d4jvdaqfljg664v62aq/public key";
      };
    };
    sops.secrets.github_ssh_auth = {
      sopsFile = config.sops.opSecrets.git_ssh.fullPath;
      key = "github_auth";
      owner = host.username;
    };
    sops.secrets.github_ssh_signing = {
      sopsFile = config.sops.opSecrets.git_ssh.fullPath;
      key = "github_signing";
      owner = host.username;
    };
    sops.secrets.forgejo_key = {
      sopsFile = config.sops.opSecrets.git_ssh.fullPath;
      key = "forgejo";
      owner = host.username;
    };
  };

  codeHosts = {
    "github.com" = [
      config.sops.secrets.github_ssh_auth.path
      config.sops.secrets.github_ssh_signing.path
    ];
    ${xelib.apps.forgejo.domain} = [
      config.sops.secrets.forgejo_key.path
      config.sops.secrets.github_ssh_signing.path
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
