{
  config,
  host,
  ...
}:
{
  home-manager.importAll = [ ./rclone.hm.nix ];

  sops.secrets.rclone-pcloud_token = {
    sopsFile = config.sops.opSecrets.rclone.fullPath;
    key = "rclone-pcloud_token";
    owner = host.username;
  };
  sops.opSecrets.rclone.keys.rclone-pcloud_token =
    "op://Private/k3ixcrzwsqpl6wjnffg2co3bda/vzpq5ej7dhbolpakiabeell73e";
}
