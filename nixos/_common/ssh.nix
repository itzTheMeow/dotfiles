{
  config,
  lib,
  xelib,
  ...
}:
let
  mkHostSSHItem = id: opts: {
    name = opts.name or (xelib.toTitleCase id);
    host = xelib.hosts.${id}.ip;
    args = "${xelib.hosts.${id}.username}@${xelib.hosts.${id}.ip}";
    inherit (xelib.hosts.${id}) publicKey;
    extraOptions = {
      Port = xelib.hosts.${id}.ports.ssh;
      ForwardAgent = true;
    }
    // (opts.extraOptions or { });
  };

  machines = [
    (mkHostSSHItem "pete" { })
    (mkHostSSHItem "hyzenberg" { })
    (mkHostSSHItem "ehrman" { })
    (mkHostSSHItem "huell" { })
    (mkHostSSHItem "ipadpro" { name = "iPad Pro"; })
    (mkHostSSHItem "ipad4" {
      name = "iPad 4";
      extraOptions = {
        # ipad openssh version isnt new enough for this
        WarnWeakCrypto = false;
      };
    })

    {
      name = "Macintosh";
      host = "macintosh.xela.internal";
      args = "meow@macintosh.xela.internal";
      publicKey = "op://Private/Macintosh SSH Key/public key";
    }
  ]
  # machines from satellite dotfiles repos (nvstly), defined in its hosts.nix
  ++ map (id: mkHostSSHItem id { }) (builtins.attrNames xelib.externalHosts);
in
lib.mkMerge [
  (xelib.mkSSHSecrets machines)

  {
    home-manager.importUser = [
      (
        hm:
        let
          sshConfig = xelib.mkSSHConfig config machines hm;
        in
        {
          programs.ssh = {
            enable = true;
            enableDefaultConfig = false;
            # machine blocks and code hosts all entryBefore "*", so this ends up last
            settings = sshConfig.programs.ssh.settings // {
              "*" = lib.optionalAttrs xelib.isDesktop {
                IdentityAgent = "~/.1password/agent.sock";
              };
            };
          };
          xdg.desktopEntries = sshConfig.xdg.desktopEntries;

          # keep the config user-owned, ssh refuses to read it otherwise
          home.hijackEditable.".ssh/config".mode = "600";
        }
      )
    ];
  }
]
