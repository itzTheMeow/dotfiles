{
  config,
  host,
  xelib,
  ...
}:
let
  basePorts = {
    tailscale = 41640;
    stun = 3480;
    socks5 = 61230;
  };
  envDir = "/run/mullvad-exit";
  configDir = "/var/lib/mullvad-exit";
  MTU = "1420";

  mkMullvadExitNode =
    cfg:
    let
      gluetunContainer = "mullvad-exit-gluetun-${cfg.name}";
    in
    [
      {
        name = gluetunContainer;
        value = {
          image = "qmcgaw/gluetun:v3.40.2";
          autoStart = true;
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/net/tun:/dev/net/tun"
          ];
          environment = {
            VPN_SERVICE_PROVIDER = "mullvad";
            VPN_TYPE = "wireguard";
            WIREGUARD_PRIVATE_KEY = cfg.privateKeySecret;
            WIREGUARD_ADDRESSES = cfg.wireguardAddress;
            SERVER_CITIES = cfg.serverCity;
            DNS_ADDRESS = "10.64.0.1";
            WIREGUARD_MTU = MTU;
            FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24,100.64.0.0/10";
          };
          environmentFiles = [
            config.sops.secrets.mullvad-exit-nodes.path
          ];
          ports = [
            "${toString (basePorts.tailscale + cfg.index)}:41641/udp"
            "${toString (basePorts.stun + cfg.index)}:3478/udp"
            "${host.ip}:${toString (basePorts.socks5 + cfg.index)}:1080"
          ];
        };
      }
      {
        name = "mullvad-exit-tailscale-${cfg.name}";
        value = {
          image = "tailscale/tailscale:v1.98.4";
          autoStart = true;
          dependsOn = [ gluetunContainer ];
          extraOptions = [
            "--network=container:${gluetunContainer}"
            "--privileged"
          ];
          environment = {
            TS_EXTRA_ARGS = "--login-server=${xelib.apps.headscale.url} --advertise-exit-node --accept-dns=false";
            TS_STATE_DIR = "/var/lib/tailscale";
            TS_HOSTNAME = cfg.tailscaleHostName;
            TS_DEBUG_MTU = MTU;
          };
          environmentFiles = [ "${envDir}/${cfg.name}.env" ];
          volumes = [ "${configDir}/${cfg.name}:/var/lib/tailscale" ];
        };
      }
      {
        name = "mullvad-exit-socks5-${cfg.name}";
        value = {
          image = "serjs/go-socks5-proxy:v0.0.4";
          autoStart = true;
          dependsOn = [ gluetunContainer ];
          extraOptions = [ "--network=container:${gluetunContainer}" ];
          environment.PROXY_PORT = 1080;
        };
      }
    ];
in
{
  # create the actual containers for each exit node
  virtualisation.oci-containers.containers = builtins.listToAttrs (
    builtins.concatLists (map mkMullvadExitNode xelib.exitNodes)
  );

  # open ports in firewall for tailscale/stun
  networking.firewall.allowedUDPPorts = builtins.concatLists (
    builtins.map (node: [
      (basePorts.tailscale + node.index)
      (basePorts.stun + node.index)
    ]) xelib.exitNodes
  );

  # enable IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # create .env files for tailscale auth keys
  systemd.tmpfiles.rules = [
    "d ${envDir} 0700 root root - -"
  ]
  ++ (builtins.map (
    node: "f+ ${envDir}/${node.name}.env 0600 root root - - TS_AUTHKEY="
  ) xelib.exitNodes);

  sops.envFiles.mullvad-exit-nodes = {
    WIREGUARD_ADDRESSES = "op://Private/marehbn7mhvixiywnnggztiosm/nxqiv6oggpwqdm7asdn4s4pzcu/Address";
    WIREGUARD_PRIVATE_KEY = "op://Private/marehbn7mhvixiywnnggztiosm/nxqiv6oggpwqdm7asdn4s4pzcu/Private Key";
  };
}
