let
  EVERY_6H = "*-*-* 00,06,12,18:00:00";
in
{
  hosts = {
    # HP Laptop
    flynn = {
      username = "xela";
      fullname = "Alex";
      ip = "100.64.0.19";
      accent = "#cba6f7"; # Mauve
      flags = [
        "gui"
        "kde"
        "gaming"
        "workstation"
      ];
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
      ip = "100.64.0.13";
      accent = "#a6e3a1"; # Green
      flags = [
        "gui"
        "kde"
        "gaming"
      ];
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
      accent = "#f38ba8"; # Red
      flags = [ "headless" ];
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
      accent = "#89dceb"; # Sky
      flags = [ "headless" ];
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
      accent = "#eba0ac"; # Maroon
      flags = [ "headless" ];
      ports = {
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

  services = {
    beszel = {
      host = "hyzenberg";
      port = 48976;
      domain = "beszel.xela";
    };
    headplane = {
      host = "ehrman";
      port = 18889;
      domain = "headplane.xela";
    };
    headscale = {
      host = "ehrman";
      port = 18888;
      domain = "pond.whenducksfly.com";
    };
    homepage = {
      host = "hyzenberg";
      port = 50983;
      domain = "xela.internal";
    };
    nzbget = {
      host = "hyzenberg";
      port = 58815;
      domain = "nzbget.xela";
    };
    pocket-id = {
      host = "ehrman";
      port = 11171;
      domain = "auth.xela.codes";
    };
    radarr = {
      host = "hyzenberg";
      port = 47878;
      domain = "radarr.xela";
    };
    prowlarr = {
      host = "hyzenberg";
      port = 49696;
      domain = "prowlarr.xela";
    };
    sonarr = {
      host = "hyzenberg";
      port = 48989;
      domain = "sonarr.xela";
    };
    step-ca = {
      host = "hyzenberg";
      port = 44433;
    };
  };
}
