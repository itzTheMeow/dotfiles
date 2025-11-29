{ utils, ... }:
let
  mkSSHConfig =
    machines:
    let
      mkMachine =
        {
          host,
          keyName,
          publicKey,
          extraOptions ? { },
        }:
        {
          inherit host;
          localPubKeyPath = ".ssh/${keyName}.pub";
          pubKeyOpPath = publicKey;
          sshOptions = {
            identityFile = "~/.ssh/${keyName}.pub";
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
    host = "hyzen.xela.codes";
    keyName = "hyzenberg";
    publicKey = "op://Personal/Hyzenberg SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    host = "ipad";
    keyName = "ipad";
    publicKey = "op://Private/iPad SSH Key/public key";
  }
  {
    host = "pi.nvst.ng";
    keyName = "pi";
    publicKey = "op://NVSTly/Raspberry PI SSH Key/public key";
  }
  {
    host = "odroid.nvst.ng";
    keyName = "odroid";
    publicKey = "op://NVSTly/Odroid SSH Key/public key";
    extraOptions = {
      port = 2222;
      forwardAgent = true;
    };
  }
  {
    host = "doris.nvst.ng";
    keyName = "doris";
    publicKey = "op://NVSTly/so7nrwf4gv2uhfsd6qx24gkgz4/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    host = "jade.nvst.ly";
    keyName = "jade";
    publicKey = "op://NVSTly/Jade SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    host = "usest1.netro.host";
    keyName = "netro";
    publicKey = "op://Private/NetroHost SSH/public key";
  }
]
