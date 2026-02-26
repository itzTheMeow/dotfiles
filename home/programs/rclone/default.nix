{
  config,
  lib,
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
      pcloud.config = {
        type = "pcloud";
        hostname = "api.pcloud.com";
      };
    };
  };

  sops.secrets.rclone = {
    sopsFile = ../../../${config.sops.opSecrets.rclone.path};
  };
  sops.opSecrets.rclone = {
    format = "dotenv";
    keys = {
      RCLONE_CONFIG_PCLOUD_TOKEN = "op://Private/k3ixcrzwsqpl6wjnffg2co3bda/vzpq5ej7dhbolpakiabeell73e";
    };
  };
}
