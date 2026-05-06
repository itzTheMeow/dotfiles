{ config, host, ... }:
{
  home-manager.importUser = [ ./rclone.hm.nix ];

  sops.secrets.pcloud-sftp-authorizedkeys = {
    sopsFile = config.sops.opSecrets.rclone.fullPath;
    key = "pcloud-sftp-authorizedkeys";
    owner = host.username;
  };
  sops.opSecrets.rclone.keys.pcloud-sftp-authorizedkeys =
    "op://Private/hl57o5bovxionexdk4cahxzr5y/public key";
}
