{
  config,
  host,
  pkgs,
  ...
}:
{
  boot.loader = {
    systemd-boot = {
      enable = true;
      memtest86.enable = true;
    };
    timeout = 3;
    efi.canTouchEfiVariables = true;
  };

  # most of this is from this PR: https://github.com/NixOS/nixpkgs/pull/428353
  # and this VM: https://git.allpurposem.at/mat/bigscreen-waydroid-vm/src/commit/d5a30a4cc69065a84c4ae16b59b54d8b06174347/configuration.nix
  services = {
    displayManager = {
      autoLogin = {
        enable = true;
        user = host.username;
      };
      defaultSession = "plasma-bigscreen-wayland";
      sessionPackages = [ pkgs.kdePackages.plasma-bigscreen ];
    };
  };

  xdg.portal.configPackages = [ pkgs.kdePackages.plasma-bigscreen ];
  environment.systemPackages = [ pkgs.kdePackages.plasma-bigscreen ];

  sops.secrets.user_key = {
    sopsFile = config.sops.opSecrets.user_key.fullPath;
    key = "private_key";
    owner = host.username;
  };
  sops.opSecrets.user_key.keys.private_key =
    "op://Private/wd7y5xz4qgp5loohnmc4wrj3t4/private key?ssh-format=openssh";
}
