{ utils, ... }:
utils.mkSSHConfig [
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
    host = "usest1.netro.host";
    args = "meow@usest1.netro.host -p 2034";
    publicKey = "op://Private/NetroHost SSH/public key";
  }
]
