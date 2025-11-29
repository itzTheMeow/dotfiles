{ utils, ... }:
let
  mkSSHConfig =
    machines:
    let
      mkMachine =
        {
          name,
          host,
          publicKey,
          extraOptions ? { },
        }:
        {
          inherit host;
          localPubKeyPath = ".ssh/${host}.pub";
          pubKeyOpPath = publicKey;
          sshOptions = {
            identityFile = "~/.ssh/${host}.pub";
            identitiesOnly = true;
          }
          // extraOptions;
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
    };
in
mkSSHConfig [
  {
    name = "Hyzenberg";
    host = "hyzen.xela.codes";
    publicKey = "op://Personal/Hyzenberg SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    name = "iPad";
    host = "ipad";
    publicKey = "op://Private/iPad SSH Key/public key";
  }
  {
    name = "Raspberry PI";
    host = "pi.nvst.ng";
    publicKey = "op://NVSTly/Raspberry PI SSH Key/public key";
  }
  {
    name = "ODROID";
    host = "odroid.nvst.ng";
    publicKey = "op://NVSTly/Odroid SSH Key/public key";
    extraOptions = {
      port = 2222;
      forwardAgent = true;
    };
  }
  {
    name = "Doris";
    host = "doris.nvst.ng";
    publicKey = "op://NVSTly/so7nrwf4gv2uhfsd6qx24gkgz4/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    name = "Jade";
    host = "jade.nvst.ly";
    publicKey = "op://NVSTly/Jade SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    name = "NetroHost";
    host = "usest1.netro.host";
    publicKey = "op://Private/NetroHost SSH/public key";
  }
]
