{ pkgs, utils, ... }:
let
  mkSSHConfig =
    machines:
    let
      mkMachine =
        {
          host,
          publicKey,
          name ? host,
          args ? host,
          extraOptions ? { },
        }:
        let
          keyName = pkgs.lib.strings.stringAsChars (
            c: if builtins.match "[a-z0-9]" c != null then c else ""
          ) (pkgs.lib.strings.toLower name);
        in
        {
          inherit host keyName;
          localPubKeyPath = ".ssh/${keyName}.pub";
          pubKeyOpPath = publicKey;
          sshOptions = {
            identityFile = "~/.ssh/${keyName}.pub";
            identitiesOnly = true;
          }
          // extraOptions;

          desktopEntry = {
            type = "Application";
            name = "SSH ${name} (${host})";
            genericName = "Terminal emulator";
            comment = "Fast, feature-rich, GPU based terminal";
            exec = "kitty --session ./sessions/ssh-${keyName}.conf";
            icon = "kitty";
            categories = [
              "System"
              "TerminalEmulator"
            ];
          };
          sessionFile = {
            ".config/kitty/sessions/ssh-${keyName}.conf" = {
              text = ''
                cd ~
                focus
                focus_os_window
                launch --title "${name} (${host})" ${builtins.toString ../../scripts/sshkitten.sh} ${args}
              '';
            };
          };
        };

      processedMachines = map mkMachine machines;
    in
    {
      files = builtins.foldl' (
        acc: machine: acc // (utils.mkSecretFile machine.localPubKeyPath machine.pubKeyOpPath)
      ) { } processedMachines;

      blocks = builtins.foldl' (
        acc: machine: acc // { "${machine.host}" = machine.sshOptions; }
      ) { } processedMachines;

      kittySessions = builtins.foldl' (acc: machine: acc // machine.sessionFile) { } processedMachines;

      desktopEntries = builtins.foldl' (
        acc: machine: acc // { "ssh-${machine.keyName}" = machine.desktopEntry; }
      ) { } processedMachines;
    };
in
mkSSHConfig [
  {
    name = "Hyzenberg";
    host = "hyzen.xela.codes";
    args = "root@hyzen.xela.codes";
    publicKey = "op://Personal/Hyzenberg SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    name = "iPad";
    host = "ipad";
    args = "mobile@ipad";
    publicKey = "op://Private/iPad SSH Key/public key";
  }
  {
    name = "Jade";
    host = "jade.nvst.ly";
    args = "root@jade.nvst.ly";
    publicKey = "op://NVSTly/Jade SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    name = "ODROID";
    host = "odroid.nvst.ng";
    args = "odroid@odroid.nvst.ng";
    publicKey = "op://NVSTly/Odroid SSH Key/public key";
    extraOptions = {
      port = 2222;
      forwardAgent = true;
    };
  }
  {
    name = "Raspberry PI";
    host = "pi.nvst.ng";
    args = "th@pi.nvst.ng";
    publicKey = "op://NVSTly/Raspberry PI SSH Key/public key";
  }
  {
    name = "NetroHost";
    host = "usest1.netro.host";
    args = "meow@usest1.netro.host -p 2034";
    publicKey = "op://Private/NetroHost SSH/public key";
  }
]
