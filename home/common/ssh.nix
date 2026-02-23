{ xelib, ... }:
let
  mkHostSSHItem = name: {
    name = xelib.toTitleCase name;
    host = xelib.hosts.${name}.ip;
    args = "${xelib.hosts.${name}.username}@${xelib.hosts.${name}.ip}";
    publicKey = xelib.hosts.${name}.publicKey;
    extraOptions = {
      port = xelib.hosts.${name}.ports.ssh;
      forwardAgent = true;
    };
  };
in
xelib.mkSSHConfig [
  {
    name = "Old Hyzenberg";
    host = "hyzen.xela.codes";
    args = "root@hyzen.xela.codes";
    publicKey = "op://Private/Hyzenberg SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  (mkHostSSHItem "hyzenberg")
  (mkHostSSHItem "ehrman")
  {
    name = "Macintosh";
    host = "macintosh.xela.internal";
    args = "meow@macintosh.xela.internal";
    publicKey = "op://Private/Macintosh SSH Key/public key";
  }
  {
    name = "iPad";
    host = "ipad.xela.internal";
    args = "mobile@ipad.xela.internal";
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
    host = "odroid.xela.internal";
    args = "odroid@odroid.xela.internal";
    publicKey = "op://NVSTly/Odroid SSH Key/public key";
    extraOptions = {
      port = 2222;
      forwardAgent = true;
    };
  }
  {
    name = "Raspberry PI";
    host = "raspberrypi.xela.internal";
    args = "th@raspberrypi.xela.internal";
    publicKey = "op://NVSTly/Raspberry PI SSH Key/public key";
  }
  {
    name = "NetroHost";
    host = xelib.hosts.huell.ip;
    args = "${xelib.hosts.huell.username}@${xelib.hosts.huell.ip} -p 2034";
    publicKey = "op://Private/2rjhliu5gsrclcan6bdt6fz4cy/public key";
  }
]
