{
  config,
  host,
  pkgs,
  ...
}:
let
  app = config.apps.webdav;
in
{
  # serve the webdav directory
  programs.rclone.remotes.pcloud.serve."/Misc/AppData/webdav" = {
    enable = true;
    protocol = "webdav";
    options = {
      addr = "${app.ip}:${app.portString}";
      htpasswd = config.sops.secrets.webdav-htpasswd.path;
    };
  };
  systemd.user.services."rclone-serve:.Misc.AppData.webdav@pcloud.service".serviceConfig.ExecStartPre =
    pkgs.writeShellScript "wait-for-tailscale-ip" ''
      until ip route get ${host.ip} >/dev/null 2>&1; do
        sleep 2
      done
    '';
}
