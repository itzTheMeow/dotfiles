{ host, ... }:
{
  home-manager.importUser = [ ./rclone.hm.nix ];

  sops.groups.rclone.pcloud-sftp-authorizedkeys = {
    value = "op://Private/hl57o5bovxionexdk4cahxzr5y/public key";
    owner = host.username;
  };
}
