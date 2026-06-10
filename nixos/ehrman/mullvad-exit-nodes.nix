{
  config,
  host,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  basePorts = {
    tailscale = 51640;
    stun = 53480;
    socks5 = 61230;
  };
  envDir = "/run/mullvad-exit";
  configDir = "/var/lib/mullvad-exit";
  MTU = "1420";

  mkMullvadExitNode =
    cfg:
    let
      gluetunContainer = "mullvad-exit-gluetun-${cfg.name}";
      tailscaleContainer = "mullvad-exit-tailscale-${cfg.name}";
      socks5Container = "mullvad-exit-socks5-${cfg.name}";
      tailscalePort = basePorts.tailscale + cfg.index;
      stunPort = basePorts.stun + cfg.index;
      extraOptions = [
        "--sysctl=net.ipv4.ip_forward=1"
        "--sysctl=net.ipv6.conf.all.forwarding=1"
        "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
      ];
    in
    {
      virtualisation.oci-containers.containers = {
        ${gluetunContainer} = {
          image = "qmcgaw/gluetun:v3.40.2";
          autoStart = true;
          inherit extraOptions;
          capabilities.NET_ADMIN = true;
          devices = [ "/dev/net/tun:/dev/net/tun" ];
          environment = {
            VPN_SERVICE_PROVIDER = "mullvad";
            VPN_TYPE = "wireguard";
            SERVER_CITIES = cfg.city;
            DNS_ADDRESS = "10.64.0.1";
            WIREGUARD_MTU = MTU;
            WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL = "25s";
            FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24,100.64.0.0/10,172.17.0.0/16";
            FIREWALL_INPUT_PORTS = "41641,3478,1080";
            HEALTH_VPN_DURATION_INITIAL = "30s";
            HEALTH_VPN_DURATION_ADDITION = "10s";
            HEALTH_SUCCESS_WAIT_DURATION = "5s";
          };
          environmentFiles = [ config.sops.secrets."mullvad-exit-node-${cfg.name}".path ];
          ports = [
            "${toString tailscalePort}:41641/udp"
            "${toString stunPort}:3478/udp"
            "${host.ip}:${toString (basePorts.socks5 + cfg.index)}:1080"
          ];
        };

        ${tailscaleContainer} = {
          image = "tailscale/tailscale:v1.98.4";
          autoStart = true;
          inherit extraOptions;
          dependsOn = [ gluetunContainer ];
          capabilities = {
            NET_ADMIN = true;
            NET_RAW = true;
          };
          privileged = true;
          networks = [ "container:${gluetunContainer}" ];
          environment = {
            TS_EXTRA_ARGS = "--login-server=${xelib.apps.headscale.url} --advertise-exit-node --accept-dns=false";
            TS_STATE_DIR = "/var/lib/tailscale";
            TS_HOSTNAME = "mullvad-${cfg.name}";
            TS_DEBUG_MTU = MTU;
          };
          environmentFiles = [ "${envDir}/${cfg.name}.env" ];
          volumes = [ "${configDir}/${cfg.name}:/var/lib/tailscale" ];
        };

        ${socks5Container} = {
          image = "serjs/go-socks5-proxy:v0.0.4";
          autoStart = true;
          dependsOn = [ gluetunContainer ];
          networks = [ "container:${gluetunContainer}" ];
          environment.REQUIRE_AUTH = "false";
        };
      };

      systemd.services =
        let
          waitForHealthy = pkgs.writeShellScript "wait-for-gluetun-${cfg.name}" ''
            echo "Waiting for ${gluetunContainer} to be healthy..."
            until [ "$(${pkgs.docker}/bin/docker inspect --format='{{.State.Health.Status}}' ${gluetunContainer} 2>/dev/null)" = "healthy" ]; do
              sleep 2
            done
            echo "${gluetunContainer} is healthy"
          '';

          # watches gluetun health and restarts only tailscale+socks5 when it
          # recovers — does NOT restart gluetun itself, avoiding cascade failures
          watcherScript = pkgs.writeShellScript "gluetun-watcher-${cfg.name}" ''
            echo "Starting gluetun health watcher for ${cfg.name}..."
            WAS_HEALTHY=true

            while true; do
              sleep 15

              STATUS=$(${pkgs.docker}/bin/docker inspect \
                --format='{{.State.Health.Status}}' \
                ${gluetunContainer} 2>/dev/null)

              if [ "$STATUS" != "healthy" ]; then
                if [ "$WAS_HEALTHY" = "true" ]; then
                  echo "WARNING: ${gluetunContainer} went unhealthy, stopping dependents..."
                  # stop tailscale and socks5 cleanly so they don't linger
                  # in a broken state while gluetun recovers
                  ${pkgs.docker}/bin/docker stop ${tailscaleContainer} 2>/dev/null || true
                  ${pkgs.docker}/bin/docker stop ${socks5Container} 2>/dev/null || true
                fi
                WAS_HEALTHY=false
                continue
              fi

              if [ "$WAS_HEALTHY" = "false" ]; then
                echo "${gluetunContainer} recovered, restarting dependents..."
                sleep 3
                ${pkgs.docker}/bin/docker start ${tailscaleContainer} 2>/dev/null || true
                ${pkgs.docker}/bin/docker start ${socks5Container} 2>/dev/null || true
                WAS_HEALTHY=true
                echo "Dependents restarted"
              fi
            done
          '';
        in
        {
          "docker-${tailscaleContainer}".serviceConfig = {
            ExecStartPre = waitForHealthy;
            Restart = "unless-stopped";
          };
          "docker-${socks5Container}".serviceConfig.ExecStartPre = waitForHealthy;

          "mullvad-exit-watcher-${cfg.name}" = {
            description = "Gluetun health watcher for ${cfg.name}";
            after = [
              "docker-${gluetunContainer}.service"
              "docker-${tailscaleContainer}.service"
            ];
            requires = [
              "docker-${gluetunContainer}.service"
              "docker-${tailscaleContainer}.service"
            ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              Restart = "always";
              RestartSec = "15s";
              ExecStart = watcherScript;
            };
          };
        };

      # open ports in firewall for tailscale/stun
      networking.firewall.allowedUDPPorts = [
        tailscalePort
        stunPort
      ];

      # create .env file for tailscale auth key
      systemd.tmpfiles.rules = [ "f+ ${envDir}/${cfg.name}.env 0600 root root - TS_AUTHKEY=" ];

      # wireguard key/addr
      sops.envFiles."mullvad-exit-node-${cfg.name}" = {
        WIREGUARD_ADDRESSES = "op://Private/marehbn7mhvixiywnnggztiosm/${cfg.name}/Address";
        WIREGUARD_PRIVATE_KEY = "op://Private/marehbn7mhvixiywnnggztiosm/${cfg.name}/Private Key";
      };
    };
in
lib.mkMerge (
  [
    {
      # enable IP forwarding
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };

      # create .env dir
      systemd.tmpfiles.rules = [ "d ${envDir} 0700 root root - -" ];
    }
  ]
  # map config for each exit node
  ++ (map mkMullvadExitNode xelib.exitNodes)
)
