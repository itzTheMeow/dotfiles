{
  config,
  host,
  lib,
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
    in
    {
      virtualisation.oci-containers.containers = {
        ${gluetunContainer} = {
          image = "qmcgaw/gluetun:v3.40.2";
          autoStart = true;
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/net/tun:/dev/net/tun"
            "--sysctl=net.ipv6.conf.all.disable_ipv6=0"
          ];
          environment = {
            VPN_SERVICE_PROVIDER = "mullvad";
            VPN_TYPE = "wireguard";
            SERVER_CITIES = cfg.city;
            DNS_ADDRESS = "10.64.0.1";
            WIREGUARD_MTU = MTU;
            FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24,100.64.0.0/10,172.17.0.0/16";
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
          dependsOn = [ gluetunContainer ];
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--cap-add=NET_RAW"
            "--device=/dev/net/tun:/dev/net/tun"
            "--network=container:${gluetunContainer}"
            "--privileged"
          ];
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
          extraOptions = [ "--network=container:${gluetunContainer}" ];
          environment.REQUIRE_AUTH = "false";
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
