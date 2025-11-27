{
  config,
  pkgs,
  utils,
  ...
}:
{
  imports = [
    ../programs/kitty
  ];

  home = {
    packages = with pkgs; [
      # vscode nix editing
      nixfmt-rfc-style
      nixd

      # development
      #bun
      cargo
      deno

      # fonts
      nerd-fonts.caskaydia-mono

      # tools
      immich-cli
    ];

    file = {
      ".config/immich/auth.yml".text = ''
        url: https://immich.xela.codes/api
        key: ${utils.secretPlaceholder "IMMICH_KEY"}
        test: ${config.programs.onepassword-secrets.secretPaths.immichKey}
      '';
      ".config/1Password/ssh/agent.toml".text = ''
        [[ssh-keys]]
        vault = "Private"
        [[ssh-keys]]
        vault = "NVSTly"
        [[ssh-keys]]
        vault = "NVSTly Internal"
      '';
    };

    sessionVariables = {
      VISUAL = "code --wait";
    };
  };
  fonts.fontconfig.enable = true;

  programs = {
    git = {
      signing = {
        format = "ssh";
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUZNxXcceFgiGEGJlvFM1DLaYFMOYO+oVfVmCcUqXRw";
        signer =
          if pkgs.stdenv.isDarwin then
            "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
          else
            "/opt/1Password/op-ssh-sign";
        signByDefault = true;
      };
      # borrowed from https://github.com/bobvanderlinden/nixos-config/blob/0c09c5c162413816d3278c406d85c05f0010527c/home/default.nix#L938
      settings.url."git@github.com:".insteadOf = [
        "https://github.com/"
        "github:"
      ];
    };
    onepassword-secrets.desktopIntegration = "Meow";
  };
}
