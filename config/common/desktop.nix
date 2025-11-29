{
  home-manager,
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
      ".config/1Password/ssh/agent.toml".text = ''
        [[ssh-keys]]
        vault = "Private"
        [[ssh-keys]]
        vault = "NVSTly"
        [[ssh-keys]]
        vault = "NVSTly Internal"
      '';
    }
    // utils.mkSecretFile ".config/immich/auth.yml" ''
      url: https://immich.xela.codes/api
      key: {{op://Personal/Immich/API Keys/CLI}}
    ''
    // utils.mkSecretFile ".ssh/hyzenberg.pub" "op://Personal/Hyzenberg SSH Key/public key";

    # prompts for 1password cli install, since we can't install via nix for desktop integration
    activation.install1PasswordCLI = home-manager.lib.hm.dag.entryAfter [ "installPackages" ] ''
      if [ ! -f /usr/local/bin/op ]; then
        cp ${pkgs._1password-cli}/bin/op /tmp/op-cli
        cat << 'EOF' > /tmp/install_op.sh
      #!/bin/bash
      sudo mv /tmp/op-cli /usr/local/bin/op
      sudo chgrp onepassword-cli /usr/local/bin/op
      sudo chmod g+s /usr/local/bin/op
      rm /tmp/install_op.sh
      echo "Install complete."
      EOF
        chmod +x /tmp/install_op.sh
        echo "Please run /tmp/install_op.sh to complete 1Password CLI installation"
      fi
    '';

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
  };
}
