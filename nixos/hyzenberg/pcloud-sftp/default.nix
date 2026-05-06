{ config, ... }:
{
  sops.secrets.pcloud-sftp-authorizedkeys = {
    sopsFile = config.sops.opSecrets.rclone.fullPath;
    key = "pcloud-sftp-authorizedkeys";
  };
  sops.opSecrets.rclone.keys.pcloud-sftp-authorizedkeys =
    "op://Private/hl57o5bovxionexdk4cahxzr5y/public key";
}
