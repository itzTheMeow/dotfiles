let
  EVERY_6H = "*-*-* 00,06,12,18:00:00";
in
{
  /*
    * username
    *   The username used for the main account on the host.
    * fullname
    *   The account "description" or full name.
    * ip
    *   The tailscale IP address.
    * type
    *   The type(s) of the device. Nested types should be both included in the list.
    *   "headless":  No GUI, just a server.
    *     "external":  Untrusted external server with minimal features.
    *   "desktop":   Any device with a GUI.
    *     "kde":       The GUI of choice is KDE Plasma.
    *     "console":   The device is a "console". (currently just bigscreen tv)
    * accent
    *   Accent color to use in some places. (mainly terminal)
    *   Must be a hex color, catppuccin mocha.
    * ports
    *   List of common ports for shared services.
    * publicKey
    *   1Password URI to the public key for SSH.
    * backupFrequency
    *   The frequency to run rustic backups on the host.
  */

  hosts = {
    # HP Laptop
    flynn = {
      username = "xela";
      fullname = "Alex";
      ip = "100.64.0.25";
      type = [
        "desktop"
        "kde"
      ];
      accent = "#cba6f7"; # Mauve
      ports = {
        beszel-agent = 45876;
        ssh = 19487;
      };
      publicKey = "op://Private/kghbljh73rgjxgoyq2rr2frtaa/public key";
      backupFrequency = "05:00";
    };
    # ODROID H4 Ultra
    pete = {
      username = "tv";
      fullname = "TV";
      ip = "100.64.0.19";
      type = [
        "desktop"
        "kde"
        "console"
      ];
      accent = "#a6e3a1"; # Green
      ports = {
        beszel-agent = 59779;
        ssh = 40938;
      };
      publicKey = "op://Private/srsyuq6y32smf66o3cz4fxlqwy/public key";
      backupFrequency = "00:00";
    };

    # Main Server
    hyzenberg = {
      username = "walt";
      ip = "100.64.0.3";
      type = [ "headless" ];
      accent = "#f38ba8"; # Red
      ports = {
        beszel-agent = 59835;
        ssh = 12896;
      };
      publicKey = "op://Private/eka63wejfdkiypenxptm6xky54/public key";
      backupFrequency = EVERY_6H;
    };
    # Proxy Server
    ehrman = {
      username = "mike";
      ip = "100.64.0.10";
      type = [ "headless" ];
      accent = "#89dceb"; # Sky
      ports = {
        beszel-agent = 61753;
        ssh = 39877;
      };
      publicKey = "op://Private/vywbzem32jihjjvgldmz5tr5mu/public key";
      backupFrequency = EVERY_6H;
    };

    # NetroHost VM
    huell = {
      username = "huell";
      ip = "100.64.0.20";
      type = [
        "headless"
        "external"
      ];
      accent = "#eba0ac"; # Maroon
      ports = {
        beszel-agent = 49821;
        ssh = 22;
      };
      publicKey = "op://Private/2rjhliu5gsrclcan6bdt6fz4cy/public key";
      backupFrequency = EVERY_6H;
    };

    # Other hosts that arent necessarily NixOS.
    iphone = {
      ip = "100.64.0.6";
    };
    ipad = {
      username = "mobile";
      ip = "100.64.0.1";
      ports.ssh = 22;
      publicKey = "op://Private/tc37c36m3m7h6atgatorajfq4i/public key";
    };

    # other users
    brayden.ip = "100.64.0.22";

    # mac, needs organized
    macintosh = {
      accent = "#b4befe"; # Lavender
    };
  };
  # hosts that are trusted to access everything
  trustedHosts = [
    "flynn"
    "pete"
    "iphone"
    "ipad"
  ];
}
