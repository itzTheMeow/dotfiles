{
  home-manager,
  isNixOS,
  lib,
  pkgs,
  utils,
  ...
}:
let
  sshConfig = import ./ssh.nix { inherit pkgs utils; };
in
{
  imports = [
    ../programs/kitty
  ];

  home = {
    packages = with pkgs; [
      # development
      bun
      deno

      ## javascript
      nodejs_24
      pnpm_10
      tsx

      ## go
      go
      go-tools
      gopls
      tygo

      ## nix
      nixd
      nixfmt

      ## rust
      cargo

      ## shell
      shellcheck
      shfmt

      ## python
      python3
      python3Packages.numpy
      python3Packages.tkinter

      ## swift
      #swiftformat

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
    # secret files
    // utils.mkSecretFile ".config/immich/auth.yml" ''
      url: https://immich.xela.codes/api
      key: {{op://Private/Immich/API Keys/CLI}}
    ''
    # add ssh public keys
    // sshConfig.files
    // utils.mkSecretFile ".ssh/github_signing.pub" "op://Private/Github Signing SSH Key/public key"
    // utils.mkSecretFile ".ssh/github_auth.pub" "op://Private/GitHub Authentication SSH Key/public key"
    # merge in the kitty session files
    // {
      ".config/kitty/sessions/default.conf".text = ''
        cd ~
        focus
        focus_os_window
        launch
      '';
    }
    // sshConfig.kittySessions;

    # prompts for 1password cli install, since we can't install via nix for desktop integration
    # only on non-nixos
    activation.install1PasswordCLI = lib.mkIf (!isNixOS) (
      home-manager.lib.hm.dag.entryAfter [ "installPackages" ] ''
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
      ''
    );

    sessionVariables = {
      VIRTUAL_ENV_DISABLE_PROMPT = "1";
      VISUAL = "code --wait";
    };
  };
  fonts.fontconfig.enable = true;

  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [ "~/.ssh/config.private" ];
      matchBlocks = sshConfig.blocks // {
        "github.com" = {
          identityFile = [
            "~/.ssh/github_signing.pub"
            "~/.ssh/github_auth.pub"
          ];
          identitiesOnly = true;
        };
        "*" = {
          extraOptions = {
            IdentityAgent =
              if pkgs.stdenv.isDarwin then
                "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"
              else
                "~/.1password/agent.sock";
          };
        };
      };
    };

    git = {
      signing = {
        format = "ssh";
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUZNxXcceFgiGEGJlvFM1DLaYFMOYO+oVfVmCcUqXRw";
        signer =
          if isNixOS then
            "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}"
          else if pkgs.stdenv.isDarwin then
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
