{ config, xelib, ... }:
let
  app = config.apps.ntfy;
in
{
  apps.ntfy = {
    domain = "ntfy.${xelib.domain}";
    port = 12393;
    enableProxy = true;
    enableDNS = true;
  };

  services.ntfy-sh = {
    enable = true;
    settings = {
      attachment-expiry-duration = "30d";
      auth-default-access = "deny-all";
      base-url = app.url;
      behind-proxy = true;
      cache-duration = "30d";
      enable-login = true;
      listen-http = "${app.ip}:${app.portString}";
      upstream-base-url = "https://ntfy.sh";
      web-push-email-address = "vapid.1@${xelib.domain}";
      web-push-file = "/var/lib/ntfy-sh/webpush.db";
    };
    environmentFile = config.sops.secrets.ntfy-server.path;
  };
  systemd.services.ntfy-sh.after = [ "tailscale-online.service" ];

  sops.envFiles.ntfy-server = {
    NTFY_WEB_PUSH_PRIVATE_KEY = "op://Private/6hzhuyrsumkvp5cw4fymth4mqa/Web Push Key";
  };
}
