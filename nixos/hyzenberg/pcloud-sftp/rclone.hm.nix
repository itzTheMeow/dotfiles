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
  systemd.user.services."rclone-serve:.@pcloud".Service.ExecStartPre =
    pkgs.writeShellScript "wait-for-tailscale-ip" ''
      until [ "$(${config.services.tailscale.package}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r .BackendState 2>/dev/null)" = "Running" ]; do
        sleep 2
      done
    '';
}
