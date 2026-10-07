{
  config,
  host,
  lib,
  ...
}:
{
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ host.username ];
  };

  home-manager.importUser = [
    (_: {
      # ssh agent vaults
      home.file.".config/1Password/ssh/agent.toml".text = ''
        [[ssh-keys]]
        vault = "Private"
        [[ssh-keys]]
        vault = "NVSTly"
        [[ssh-keys]]
        vault = "NVSTly Internal"
      '';

      # set up git signing with 1password
      programs.git = {
        signing = {
          format = "ssh";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUZNxXcceFgiGEGJlvFM1DLaYFMOYO+oVfVmCcUqXRw";
          signer = lib.getExe' config.programs._1password-gui.package "op-ssh-sign";
          signByDefault = true;
        };
        # borrowed from https://github.com/bobvanderlinden/nixos-config/blob/0c09c5c162413816d3278c406d85c05f0010527c/home/default.nix#L938
        # switches github.com HTTP urls to use ssh
        settings.url."git@github.com:".insteadOf = [
          "https://github.com/"
          "github:"
        ];
      };
    })
  ];

  persist.ed.home.userDirectories = [ ".config/1Password" ];
}
