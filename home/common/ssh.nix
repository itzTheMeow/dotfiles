{ xelib, ... }:
xelib.mkSSHConfig [
  {
    name = "Hyzenberg";
    host = "hyzen.xela.codes";
    args = "root@hyzen.xela.codes";
    publicKey = "op://Private/Hyzenberg SSH Key/public key";
    extraOptions = {
      forwardAgent = true;
    };
  }
  {
    name = "Hyzenberg (new)";
    host = xelib.hosts.hyzenberg.ip;
    args = "${xelib.hosts.hyzenberg.username}@${xelib.hosts.hyzenberg.ip}";
    publicKey = "op://Private/eka63wejfdkiypenxptm6xky54/public key";
    extraOptions = {
      port = xelib.hosts.hyzenberg.ports.ssh;
      forwardAgent = true;
    };
  }
  {
    name = "Ehrman";
    host = xelib.hosts.ehrman.ip;
    args = "${xelib.hosts.ehrman.username}@${xelib.hosts.ehrman.ip}";
    publicKey = "op://Private/vywbzem32jihjjvgldmz5tr5mu/public key";
    extraOptions = {
      port = xelib.hosts.ehrman.ports.ssh;
      forwardAgent = true;
    };
  }
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
    publicKey = "op://Private/NetroHost SSH/public key";
  }
]
