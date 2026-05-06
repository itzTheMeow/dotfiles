{ config, host, ... }:
let
  sftpPort = 13097;
in
{
  programs.rclone.remotes.pcloud.serve."/" = {
    enable = true;
    protocol = "sftp";
    options = {
      addr = "${host.ip}:${toString sftpPort}";
      user = "pcloud";
      authorized-keys = config.sops.secrets.pcloud-sftp-authorizedkeys.path;
    };
  };
}
