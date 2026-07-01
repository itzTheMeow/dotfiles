{
  config,
  hm,
  lib,
  xelib,
  ...
}:
{
  programs.rclone = {
    enable = true;
    remotes = {
      ipad.config = {
        type = "sftp";
        host = xelib.hosts.ipad.ip;
        user = "root";
        key_use_agent = true;
        known_hosts_file = "~/.ssh/known_hosts";
        shell_type = "unix";
        md5sum_command = "md5sum";
        sha1sum_command = "sha1sum";
      }
      // lib.optionalAttrs (hm.config.sops.secrets ? "ssh_pub_ipad") {
        key_file = hm.config.sops.secrets."ssh_pub_ipad".path;
      };
      pcloud = {
        config = {
          type = "pcloud";
          hostname = "api.pcloud.com";
        };
        secrets.token = config.sops.secrets.rclone-pcloud_token.path;
      };
    };
  };
}
