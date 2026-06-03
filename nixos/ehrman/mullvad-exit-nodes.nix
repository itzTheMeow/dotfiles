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
      networkName = "mullvad-exit-net-${cfg.name}";
      tailscalePort = basePorts.tailscale + cfg.index;
      stunPort = basePorts.stun + cfg.index;
      # each exit node gets its own /29 on 172.20.x.0
      gluetunIP = "172.20.${toString cfg.index}.1";
      tailscaleIP = "172.20.${toString cfg.index}.2";
      socks5IP = "172.20.${toString cfg.index}.3";
      subnet = "172.20.${toString cfg.index}.0/29";
      extraOptions = [
        "--sysctl=net.ipv4.ip_forward=1"
        "--sysctl=net.ipv6.conf.all.forwarding=1"
        "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
      ];
    in
    {
      # define a dedicated bridge network per exit node
      virtualisation.oci-containers.networks.${networkName} = {
        ipam.config = [ { inherit subnet; } ];
      };

      virtualisation.oci-containers.containers = {
        ${gluetunContainer} = {
          image = "qmcgaw/gluetun:v3.40.2";
          autoStart = true;
          inherit extraOptions;
          capabilities.NET_ADMIN = true;
          devices = [ "/dev/net/tun:/dev/net/tun" ];
          networks = [
            "${networkName}:ipv4_address=${gluetunIP}"
          ];
          environment = {
            VPN_SERVICE_PROVIDER = "mullvad";
            VPN_TYPE = "wireguard";
            SERVER_CITIES = cfg.city;
            DNS_ADDRESS = "10.64.0.1";
            WIREGUARD_MTU = MTU;
            WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL = "25s";
            FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24,100.64.0.0/10,172.17.0.0/16";
            FIREWALL_INPUT_PORTS = "41641,3478,1080";
            # detect dead tunnels faster
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
          dependsOn = [ gluetunContainer ];
          capabilities = {
            NET_ADMIN = true;
            NET_RAW = true;
          };
          privileged = true;
          # own network namespace now — NOT network:container:gluetun
          networks = [
            "${networkName}:ipv4_address=${tailscaleIP}"
          ];
          environment = {
            TS_EXTRA_ARGS = "--login-server=${xelib.apps.headscale.url} --advertise-exit-node --accept-dns=false";
            TS_STATE_DIR = "/var/lib/tailscale";
            TS_HOSTNAME = "mullvad-${cfg.name}";
            TS_DEBUG_MTU = MTU;
          };
          environmentFiles = [ "${envDir}/${cfg.name}.env" ];
          volumes = [ "${configDir}/${cfg.name}:/var/lib/tailscale" ];
          # set default route through gluetun after container starts
          extraOptions = extraOptions ++ [
            "--add-host=gluetun:${gluetunIP}"
          ];
        };

        ${socks5Container} = {
          image = "serjs/go-socks5-proxy:v0.0.4";
          autoStart = true;
          dependsOn = [ gluetunContainer ];
          networks = [
            "${networkName}:ipv4_address=${socks5IP}"
          ];
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

          # after tailscale starts, punch a default route through gluetun
          # this replaces what network:container: was implicitly doing
          setRoute = pkgs.writeShellScript "set-route-${cfg.name}" ''
            echo "Setting default route through gluetun (${gluetunIP}) in ${tailscaleContainer}..."
            ${pkgs.docker}/bin/docker exec ${tailscaleContainer} \
              ip route replace default via ${gluetunIP} dev eth0
            echo "Route set"
          '';

          # watcher: if gluetun goes unhealthy, re-apply the route once it recovers
          # does NOT restart tailscale — just fixes the routing
          watcherScript = pkgs.writeShellScript "gluetun-watcher-${cfg.name}" ''
            echo "Starting gluetun health watcher for ${cfg.name}..."
            WAS_HEALTHY=true

            while true; do
              sleep 10

              STATUS=$(${pkgs.docker}/bin/docker inspect \
                --format='{{.State.Health.Status}}' \
                ${gluetunContainer} 2>/dev/null)

              if [ "$STATUS" != "healthy" ]; then
                echo "WARNING: ${gluetunContainer} is $STATUS"
                WAS_HEALTHY=false
                continue
              fi

              if [ "$WAS_HEALTHY" = "false" ]; then
                echo "${gluetunContainer} recovered — re-applying route in ${tailscaleContainer}"
                sleep 3
                ${pkgs.docker}/bin/docker exec ${tailscaleContainer} \
                  ip route replace default via ${gluetunIP} dev eth0 || true
                WAS_HEALTHY=true
                echo "Route restored"
              fi
            done
          '';
        in
        {
          "docker-${tailscaleContainer}" = {
            serviceConfig.ExecStartPre = waitForHealthy;
            postStart = "${setRoute}";
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
              RestartSec = "10s";
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
