{
  hosts = {
    # HP Laptop
    flynn = {
      username = "xela";
      ip = "100.64.0.19";
      accent = "#cba6f7"; # Mauve
      ports = {
        beszel-agent = 45876;
      };
    };
    # Intel Compute Stick
    pete = {
      username = "tv";
      ip = "";
      accent = "#a6e3a1"; # Green
      ports = {
        ssh = 40938;
      };
    };

    # Main Server
    hyzenberg = {
      username = "walt";
      ip = "100.64.0.3";
      accent = "#f38ba8"; # Red
      ports = {
        ssh = 12896;
      };
    };
    # Proxy Server
    ehrman = {
      username = "mike";
      ip = "100.64.0.10";
      accent = "#89dceb"; # Sky
      ports = {
        ssh = 39877;
      };
    };

    # NetroHost VM
    huell = {
      username = "huell";
      ip = "0.0.0.0";
      accent = "#eba0ac"; # Maroon
      ports = {
        ssh = 22;
      };
    };

    # mac, needs organized
    macintosh = {
      accent = "#b4befe"; # Lavender
    };
  };

  services = {
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
