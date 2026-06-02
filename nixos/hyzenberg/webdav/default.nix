{
  config,
  host,
  ...
}:
{
  home-manager.importUser = [ ./rclone.hm.nix ];

  apps.webdav = {
    domain = "webdav.xela";
    port = 39834;
    enableProxy = true;
  };

  sops.secrets.webdav-htpasswd = {
    sopsFile = config.sops.opSecrets.webdav.fullPath;
    key = "htpasswd";
    owner = host.username;
  };
  sops.opSecrets.webdav.keys.htpasswd = "op://Private/zdj2mgqfhx2lue2iehaxgejyzy/htpasswd";
}
