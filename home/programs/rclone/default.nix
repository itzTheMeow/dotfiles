{
  config,
  ...
}:
{
  programs.rclone = {
    enable = true;
    remotes = {
      ipad.config = {
        type = "sftp";
        host = "ipad.xela.internal";
        user = "mobile";
        key_use_agent = true;
        pubkey_file = "~/.ssh/ipad.pub";
        known_hosts_file = "~/.ssh/known_hosts";
        shell_type = "unix";
        md5sum_command = "md5sum";
        sha1sum_command = "sha1sum";
      };
      pcloud = {
        config = {
          type = "pcloud";
          hostname = "api.pcloud.com";
        };
        secrets.token = config.sops.secrets.rclone_pcloud_token.path;
      };
    };
  };

  sops.secrets.rclone_pcloud_token = {
    sopsFile = ../../../${config.sops.opSecrets.rclone.path};
    key = "pcloud_token";
  };
  sops.opSecrets.rclone.keys.pcloud_token =
    "op://Private/k3ixcrzwsqpl6wjnffg2co3bda/vzpq5ej7dhbolpakiabeell73e";
}
