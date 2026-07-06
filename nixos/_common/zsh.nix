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
  users.users.root.shell = pkgs.zsh;
  users.users.${host.username}.shell = pkgs.zsh;

  # persist the zsh_history directory
  persist.ed.home.userDirectories = [ ".local/share/zsh_history" ];
  persist.ed.persist.directories = [ dataDir ];

  environment.variables.ATUIN_DATA_DIR = dataDir;
  systemd.tmpfiles.rules = [ "d ${dataDir} 0755 ${host.username} users - -" ];
  programs.atuin = {
    enable = true;
    daemon.enable = true;
    # https://github.com/atuinsh/atuin/pull/2945
    # apply patch to add ATUIN_DATA_DIR support so we can relocate it
    package = pkgs.atuin.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          url = "https://github.com/atuinsh/atuin/commit/6e01ff990f223d2c0ba63742215f2af2111b87ef.patch";
          hash = "sha256-R4Oo7JgKeYwvp6Wv2YM8CZwAMsx9qy2obAWqIu9azGk=";
        })
      ];
    });
    settings = {
      key_path = config.sops.secrets.atuin-key.path;
      auto_sync = true;
      update_check = false;
      #TODO: selfhosted
      sync_address = "https://api.atuin.sh";
      sync_frequency = "10s";
      search_mode = "daemon-fuzzy";
      filter_mode_shell_up_key_binding = "host"; # default to current host history
      workspaces = true; # enable git repo filtering
    };
  };

  sops.secrets.atuin-key = {
    sopsFile = config.sops.opSecrets.atuin.fullPath;
    key = "key";
    owner = host.username;
  };
  sops.opSecrets.atuin.keys.key = "op://Private/xoqbcl4ot4tbfk4ckzp33xikoi/Encryption";
}
