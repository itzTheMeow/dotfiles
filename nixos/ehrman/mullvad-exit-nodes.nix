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
      tailscalePort = basePorts.tailscale + cfg.index;
      stunPort = basePorts.stun + cfg.index;
      extraOptions = [
        "--sysctl=net.ipv4.ip_forward=1"
        "--sysctl=net.ipv6.conf.all.forwarding=1"
        "--sysctl=net.ipv6.conf.all.disable_ipv6=0"
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
            FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24,100.64.0.0/10,172.17.0.0/16";
            FIREWALL_INPUT_PORTS = "41641,3478,1080";
          };
          environmentFiles = [ config.sops.secrets."mullvad-exit-node-${cfg.name}".path ];
          ports = [
            "${toString tailscalePort}:41641/udp"
            "${toString stunPort}:3478/udp"
            "${host.ip}:${toString (basePorts.socks5 + cfg.index)}:1080"
          ];
        };
        "mullvad-exit-tailscale-${cfg.name}" = {
          image = "tailscale/tailscale:v1.98.4";
          autoStart = true;
          inherit extraOptions;
          dependsOn = [ gluetunContainer ];
          capabilities = {
            NET_ADMIN = true;
            NET_RAW = true;
          };
          devices = [ "/dev/net/tun:/dev/net/tun" ];
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
        "mullvad-exit-socks5-${cfg.name}" = {
          image = "serjs/go-socks5-proxy:v0.0.4";
          autoStart = true;
          dependsOn = [ gluetunContainer ];
          networks = [ "container:${gluetunContainer}" ];
          environment.REQUIRE_AUTH = "false";
        };
      };

      systemd.services =
        let
          waitScript = pkgs.writeShellScript "wait-for-gluetun-${cfg.name}" ''
            until [ "$(${pkgs.docker}/bin/docker inspect --format='{{.State.Health.Status}}' ${gluetunContainer})" = "healthy" ]; do
              echo "Waiting for ${gluetunContainer} network tunnel to report healthy..."
              sleep 2
            done
          '';
        in
        {
          "docker-mullvad-exit-tailscale-${cfg.name}".serviceConfig.ExecStartPre = waitScript;
          "docker-mullvad-exit-socks5-${cfg.name}".serviceConfig.ExecStartPre = waitScript;
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
