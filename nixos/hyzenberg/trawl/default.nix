{
  config,
  lib,
  xelib,
  ...
}:
let
  app = config.apps.trawl;

  socks5BasePort = xelib.apps.mullvad-exit-nodes.details.basePorts.socks5;
  proxyPool = lib.concatStringsSep "," (
    map (
      node: "socks5://${xelib.hosts.ehrman.ip}:${toString (socks5BasePort + node.index)}"
    ) xelib.exitNodes
  );
in
{
  apps.trawl = {
    domain = "trawl.xela";
    port = 54719;
    enableProxy = true;

    name = "Trawl";
    description = "Web Fetch/Read Proxy";
  };

  virtualisation.oci-containers.containers.trawl = {
    image = "ghcr.io/germondai/trawl:1.10.1";
    autoStart = true;
    extraOptions = [ "--shm-size=1g" ];
    ports = [ "${app.ip}:${app.portString}:8191" ];
    environment = {
      TZ = config.time.timeZone;

      # markdown reader/scrape tools for open-webui (Tool Server Connection)
      MCP_ENABLED = "true";
      # server-to-server MCP clients send no Origin header; a browser-based
      # MCP client would need its exact origin listed here
      MCP_ALLOWED_ORIGINS = "";

      # keep it single-container: clearance cache is per-process
      SESSION_CACHE_DRIVER = "memory";
      BROWSER_POOL_SIZE = "1";
      # retire warm browsers after 5min idle so they don't sit in ram
      BROWSER_IDLE_TIMEOUT_MS = "300000";

      # tier 1 (plain http) egresses directly, challenges escalate through the mullvad exit nodes
      PROXY_URL = proxyPool;
      SCRAPE_PROXY_SELECTION = "failover";
    };
  };
}
