{ host, ... }: {
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ host.username ];
  };

  # ssh agent vaults
  home-manager.users.${host.username}.home.file.".config/1Password/ssh/agent.toml".text = ''
    [[ssh-keys]]
    vault = "Private"
    [[ssh-keys]]
    vault = "NVSTly"
    [[ssh-keys]]
    vault = "NVSTly Internal"
  '';

  persist.ed.home.userDirectories = [ ".config/1Password" ];
}
