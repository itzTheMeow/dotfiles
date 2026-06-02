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
  apps.webdav = {
    domain = "webdav.xela";
    port = 39834;
    enableProxy = true;
  };

  # serve the webdav directory
  home-manager.users.${host.username}.programs.rclone.remotes.pcloud.serve."/Misc/AppData/webdav" = {
    enable = true;
    protocol = "webdav";
    options = {
      addr = "${app.ip}:${app.portString}";
      htpasswd = config.sops.secrets.webdav-htpasswd.path;
    };
  };
  home-manager.users.${host.username}.systemd.user.services."rclone-serve:.Misc.AppData.webdav@pcloud.service".serviceConfig.ExecStartPre =
    pkgs.writeShellScript "wait-for-tailscale-ip" ''
      until ip route get ${host.ip} >/dev/null 2>&1; do
        sleep 2
      done
    '';

  sops.secrets.webdav-htpasswd = {
    sopsFile = config.sops.opSecrets.webdav.fullPath;
    key = "htpasswd";
    owner = host.username;
  };
  sops.opSecrets.webdav.keys.htpasswd = "op://Private/zdj2mgqfhx2lue2iehaxgejyzy/htpasswd";
}
