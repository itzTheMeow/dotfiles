{
  config,
  lib,
  xelib,
  ...
}:
let
  mkHostSSHItem = id: name: {
    name = if name != null then name else (xelib.toTitleCase id);
    host = xelib.hosts.${id}.ip;
    args = "${xelib.hosts.${id}.username}@${xelib.hosts.${id}.ip}";
    inherit (xelib.hosts.${id}) publicKey;
    extraOptions = {
      Port = xelib.hosts.${id}.ports.ssh;
      ForwardAgent = true;
    };
  };

  machines = [
    (mkHostSSHItem "pete" null)
    (mkHostSSHItem "hyzenberg" null)
    (mkHostSSHItem "ehrman" null)
    (mkHostSSHItem "huell" null)
    (mkHostSSHItem "ipad" "iPad")
    {
      name = "Macintosh";
      host = "macintosh.xela.internal";
      args = "meow@macintosh.xela.internal";
      publicKey = "op://Private/Macintosh SSH Key/public key";
    }
    {
      name = "Jade";
      host = "jade.nvst.ly";
      args = "root@jade.nvst.ly";
      publicKey = "op://NVSTly/Jade SSH Key/public key";
      extraOptions = {
        ForwardAgent = true;
      };
    }
    {
      name = "ODROID";
      host = "odroid.xela.internal";
      args = "odroid@odroid.xela.internal";
      publicKey = "op://NVSTly/Odroid SSH Key/public key";
      extraOptions = {
        Port = 2222;
        ForwardAgent = true;
      };
    }
    {
      name = "Raspberry PI";
      host = "raspberrypi.xela.internal";
      args = "th@raspberrypi.xela.internal";
      publicKey = "op://NVSTly/Raspberry PI SSH Key/public key";
    }
  ];
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
              "*" = {
                IdentityAgent = "~/.1password/agent.sock";
              };
            };
          };
          xdg.desktopEntries = sshConfig.xdg.desktopEntries;
        }
      )
    ];
  }
]
