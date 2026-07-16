{
  config,
  host,
  pkgs,
  ...
}:
let
  dataDir = "/etc/atuin/data";
in
{
  home-manager.importAll = [ ./zsh.hm.nix ];

  programs.bash.enable = true;
  programs.zsh.enable = true;

  # set as default shell
  users.defaultUserShell = pkgs.zsh;
  users.users.root.shell = pkgs.zsh;
  users.users.${host.username}.shell = pkgs.zsh;

  # keep atuin data dir persisted
  persist.ed.persist.directories = [ dataDir ];
  # set the data dir and create it
  environment.variables.ATUIN_DATA_DIR = dataDir;
  systemd.tmpfiles.rules = [ "d ${dataDir} 0755 ${host.username} users - -" ];

  sops.secrets.atuin-key = {
    sopsFile = config.sops.opSecrets.atuin.fullPath;
    key = "key";
    owner = host.username;
  };
  sops.secrets.atuin-session = {
    sopsFile = config.sops.opSecrets.atuin.fullPath;
    key = "session";
    owner = host.username;
  };
  sops.opSecrets.atuin.keys = {
    key = "op://Private/xoqbcl4ot4tbfk4ckzp33xikoi/Encryption";
    session = "op://Private/xoqbcl4ot4tbfk4ckzp33xikoi/Session";
  };
}
