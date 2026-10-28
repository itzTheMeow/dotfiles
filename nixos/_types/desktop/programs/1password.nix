{
  config,
  host,
  hostname,
  lib,
  pkgs,
  ...
}:
{
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ host.username ];
  };

  environment.sessionVariables = {
    # set the 1password ssh auth socket
    SSH_AUTH_SOCK = "/home/${host.username}/.1password/agent.sock";
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

      # add the desktop file to autostart
      xdg.autostart.entries =
        let
          f =
            #TODO:26.11 flip to using the new com.onepassword.OnePassword name
            if hostname == "pete" then
              "${pkgs._1password-gui}/share/applications/com.onepassword.OnePassword.desktop"
            else
              "${pkgs._1password-gui}/share/applications/1password.desktop";
        in
        if (builtins.elem "console" host.type) then
          [
            # on consoles, patch the desktop file to start 1password in the background (silently)
            (pkgs.runCommand "1password.desktop" { } ''
              substitute \
                "${f}" \
                "$out" \
                --replace-fail 'Exec=1password %U' 'Exec=1password --silent %U'
            '')
          ]
        else
          [ f ];

      # vscode extension settings
      programs.vscode.profiles.default.userSettings."1password.editor.suggestStorage" = false;
    })
  ];

  programs.vscode.extensions = [
    pkgs.vscode-stores.nixpkgs."1Password".op-vscode # 1Password
  ];

  persist.ed.home.userDirectories = [ ".config/1Password" ];
}
