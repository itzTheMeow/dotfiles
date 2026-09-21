{
  config,
  host,
  lib,
  xelib,
  ...
}:
let
  ipadKey = xelib.sshKeyName "ipad";
in
{
  home-manager.importAll = [
    (hm: {
      programs.rclone = {
        enable = true;
        remotes = {
          ipad = {
            config = {
              type = "sftp";
              host = xelib.hosts.ipad.ip;
              user = "root";
              key_use_agent = true;
              known_hosts_file = "~/.ssh/known_hosts";
              shell_type = "unix";
              md5sum_command = "md5sum";
              sha1sum_command = "sha1sum";
            }
            // lib.optionalAttrs (config.sops.groupPaths.ssh_pubkeys ? ${ipadKey}) {
              key_file = config.sops.groupPaths.ssh_pubkeys.${ipadKey};
            };
          };
          pcloud = {
            config = {
              type = "pcloud";
              hostname = "api.pcloud.com";
            };
            secrets.token = config.sops.groupPaths.rclone.pcloud-token;
          };
        };
      };
    })
  ];

  sops.groups.rclone.pcloud-token = {
    value = "op://Private/k3ixcrzwsqpl6wjnffg2co3bda/vzpq5ej7dhbolpakiabeell73e";
    owner = host.username;
  };
}
