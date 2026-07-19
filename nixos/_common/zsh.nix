{
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

  sops.groups.atuin.key = {
    value = "op://Private/xoqbcl4ot4tbfk4ckzp33xikoi/Encryption";
    owner = host.username;
  };
}
