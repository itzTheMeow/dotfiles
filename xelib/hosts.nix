{
  hosts = {
    # HP Laptop
    flynn = {
      username = "xela";
      ip = "100.64.0.19";
      ports = {
        beszel-agent = 45876;
      };
    };
    # Intel Compute Stick
    pete = {
      username = "tv";
      ip = "";
      ports = {
        ssh = 40938;
      };
    };

    # Main Server
    hyzenberg = {
      username = "walt";
      ip = "100.64.0.3";
      ports = {
        ssh = 12896;
      };
    };
    # Proxy Server
    ehrman = {
      username = "mike";
      ip = "100.64.0.10";
      ports = {
        ssh = 39877;
      };
    };

    # NetroHost VM
    huell = {
      username = "huell";
      ip = "0.0.0.0";
      ports = {
        ssh = 22;
      };
    };

    # mac, needs organized
    macintosh = { };
  };

  services = {
    prowlarr = {
      host = "hyzenberg";
      port = 49696;
    };
  };
}
