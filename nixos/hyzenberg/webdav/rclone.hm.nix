{
  config,
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
      htpasswd = config.sops.groupPaths.webdav.htpasswd;
    };
  };
  systemd.user.services."rclone-serve:.Misc.AppData.webdav@pcloud".Service.ExecStartPre =
    pkgs.writeShellScript "wait-for-tailscale-ip" ''
      until [ "$(${config.services.tailscale.package}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r .BackendState 2>/dev/null)" = "Running" ]; do
        sleep 2
      done
    '';
}
