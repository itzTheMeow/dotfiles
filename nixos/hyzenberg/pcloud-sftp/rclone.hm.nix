{
  config,
  host,
  pkgs,
  ...
}:
let
  sftpPort = 13097;
in
{
  programs.rclone.remotes.pcloud.serve."/" = {
    enable = true;
    protocol = "sftp";
    options = {
      addr = "${host.ip}:${toString sftpPort}";
      authorized-keys = config.sops.secrets.pcloud-sftp-authorizedkeys.path;
    };
  };
  systemd.user.services."rclone-serve:.@pcloud.service".Service.ExecStartPre =
    pkgs.writeShellScript "wait-for-tailscale-ip" ''
      until ip route get ${host.ip} >/dev/null 2>&1; do
        sleep 2
      done
    '';
}
