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
      ip = "";
      ports = {
        ssh = 39877;
      };
    };

    # temporary, needs organized
    netrohost = { };
    macintosh = { };
  };

  services = {
    prowlarr = {
      host = "hyzenberg";
      port = 49696;
    };
  };
}
