{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  imports = [
    ./ssh.nix
  ];

  home = {
    packages = with pkgs; [
      # development
      ## javascript
      bun
      deno
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

      ## protobuf
      protobuf
      protoc-gen-go
      protoc-gen-go-grpc

      ## just
      just-lsp

      ## other
      openapi-generator-cli

      ## swift
      #swiftformat
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
    };

    sessionVariables = {
      VIRTUAL_ENV_DISABLE_PROMPT = "1";
      VISUAL = "code --wait";
    };
  };

  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "github.com" = {
          identityFile = [
            config.sops.secrets.github_ssh_auth.path
            config.sops.secrets.github_ssh_signing.path
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
          if pkgs.stdenv.isDarwin then
            "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
          else
            "${lib.getExe' pkgs-unstable._1password-gui "op-ssh-sign"}";
        signByDefault = true;
      };
      # borrowed from https://github.com/bobvanderlinden/nixos-config/blob/0c09c5c162413816d3278c406d85c05f0010527c/home/default.nix#L938
      settings.url."git@github.com:".insteadOf = [
        "https://github.com/"
        "github:"
      ];
    };
  };

  sops.secrets.github_ssh_auth = {
    sopsFile = ../../${config.sops.opSecrets.github_ssh.path};
    key = "github_auth";
  };
  sops.secrets.github_ssh_signing = {
    sopsFile = ../../${config.sops.opSecrets.github_ssh.path};
    key = "github_signing";
  };
  sops.opSecrets.github_ssh = {
    keys = {
      github_auth = "op://Private/royxpwncznclgwwbtp5gq4syle/public key";
      github_signing = "op://Private/brpzxia4pb2uk7ujbyf3nj7qci/public key";
    };
  };
}
