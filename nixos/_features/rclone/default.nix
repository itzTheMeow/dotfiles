{
  host,
  ...
}:
{
  home-manager.importAll = [ ./rclone.hm.nix ];

  sops.groups.rclone.pcloud-token = {
    value = "op://Private/k3ixcrzwsqpl6wjnffg2co3bda/vzpq5ej7dhbolpakiabeell73e";
    owner = host.username;
  };
}
