{ home-manager, pkgs, ... }:
{
  # inject secrets with 1password
  home.activation.injectRcloneSecrets = (
    home-manager.lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      if [ -x /usr/local/bin/op ]; then
        OP_BIN=/usr/local/bin/op
      else
        OP_BIN=${pkgs._1password-cli}/bin/op
      fi
      $OP_BIN inject -i ~/.config/rclone/rclone.conf -o ~/.config/rclone/rclone.conf -f
    ''
  );

  programs.rclone = {
    enable = true;
    remotes = {
      backblaze.config = {
        type = "b2";
        account = "op://Private/Backblaze/Application Keys/xela-codes-nas-id";
        key = "op://Private/Backblaze/Application Keys/xela-codes-nas-applicationKey";
      };
      ipad.config = {
        type = "sftp";
        host = "ipad";
        user = "mobile";
        key_use_agent = true;
        pubkey_file = "~/.ssh/ipad.pub";
        known_hosts_file = "~/.ssh/known_hosts";
        shell_type = "unix";
        md5sum_command = "md5sum";
        sha1sum_command = "sha1sum";
      };
      pcloud.config = {
        type = "pcloud";
        hostname = "api.pcloud.com";
        token = "op://Private/pcloud.com/Auth Payload";
      };
    };
  };
}
