{ host, ... }:
{
  home-manager.importUser = [ ./rclone.hm.nix ];

  apps.webdav = {
    domain = "webdav.xela";
    port = 39834;
    enableProxy = true;
  };

  sops.groups.webdav.htpasswd = {
    value = "op://Private/zdj2mgqfhx2lue2iehaxgejyzy/htpasswd";
    owner = host.username;
  };
}
