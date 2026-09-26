{
  lib,
  pkgs-unstable,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      # development
      ## javascript
      pkgs-unstable.bun
      deno
      nodejs_24
      pnpm_10
      tsx

      ## python
      python3
      python3Packages.numpy
      python3Packages.tkinter
    ];

    sessionVariables = {
      VIRTUAL_ENV_DISABLE_PROMPT = "1";
    };
  };

  programs.git = {
    signing = {
      format = "ssh";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUZNxXcceFgiGEGJlvFM1DLaYFMOYO+oVfVmCcUqXRw";
      signer =
        if pkgs.stdenv.isDarwin then
          "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
        else
          "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
      signByDefault = true;
    };
    # borrowed from https://github.com/bobvanderlinden/nixos-config/blob/0c09c5c162413816d3278c406d85c05f0010527c/home/default.nix#L938
    settings.url."git@github.com:".insteadOf = [
      "https://github.com/"
      "github:"
    ];
  };
}
