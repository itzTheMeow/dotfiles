{ config, xelib, ... }:
let
  mkHostSSHItem = id: name: {
    name = if name != null then name else (xelib.toTitleCase id);
    host = xelib.hosts.${id}.ip;
    args = "${xelib.hosts.${id}.username}@${xelib.hosts.${id}.ip}";
    inherit (xelib.hosts.${id}) publicKey;
    extraOptions = {
      port = xelib.hosts.${id}.ports.ssh;
      forwardAgent = true;
    };
  };
in
xelib.mkSSHConfig config [
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
]
