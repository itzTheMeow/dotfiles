{ pkgs, lib, ... }:
let
  # Function to create a Mullvad exit node container
  mkMullvadExitNode =
    {
      name,
      city,
      country ? "us",
      ipSuffix,
    }:
    {
      name = "mullvad-${name}";
      value = {
        autoStart = true;
        privateNetwork = true;
        hostAddress = "10.250.0.1";
        localAddress = "10.250.0.${toString ipSuffix}";

        # Allow TUN device for VPN
        allowedDevices = [
          {
            node = "/dev/net/tun";
            modifier = "rwm";
          }
        ];

        config =
          { pkgs, ... }:
          {
            system.stateVersion = "25.11";

            networking.firewall.enable = false;
            networking.useHostResolvConf = lib.mkForce false;

            services.resolved.enable = true;
            services.resolved.extraConfig = ''
              DNS=10.64.0.1
              DNSStubListener=yes
            '';

            # Forward DNS queries to Mullvad's DNS
            networking.nameservers = [ "10.64.0.1" ];

            # Install necessary packages
            environment.systemPackages = with pkgs; [
              tailscale
              wireguard-tools
              openresolv
              # debug
              iptables
              tcpdump
            ];

            # WireGuard will be configured dynamically from configs
            # Place Mullvad configs in /var/lib/mullvad-configs/*.conf

            # Enable Tailscale
            services.tailscale.enable = true;
            services.tailscale.useRoutingFeatures = "both";

            # Systemd service to setup Mullvad WireGuard
            systemd.services.mullvad-wireguard = {
              description = "Mullvad WireGuard VPN for ${city}";
              after = [ "network-pre.target" ];
              before = [ "network.target" ];
              wants = [ "network-pre.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };

              script = ''
                CONFIG_DIR="/var/lib/mullvad-configs"

                if [ ! -d "$CONFIG_DIR" ]; then
                  echo "Config directory $CONFIG_DIR does not exist. Please create it and add Mullvad configs."
                  echo "Download configs from: https://mullvad.net/en/account/wireguard-config"
                  exit 1
                fi

                # Count available configs
                CONFIG_COUNT=$(ls -1 "$CONFIG_DIR"/*.conf 2>/dev/null | wc -l)
                if [ "$CONFIG_COUNT" -eq 0 ]; then
                  echo "No .conf files found in $CONFIG_DIR"
                  exit 1
                fi

                # Pick a random config
                RANDOM_CONFIG=$(ls -1 "$CONFIG_DIR"/*.conf | shuf -n 1)
                echo "Selected config: $(basename "$RANDOM_CONFIG")"

                # Start WireGuard with the selected config
                ${pkgs.wireguard-tools}/bin/wg-quick up "$RANDOM_CONFIG"
              '';
              /*
                  # Add iptables rule to allow Tailscale control connections before the killswitch
                  # This ensures Tailscale can authenticate even with killswitch active
                  WG_IFACE=$(${pkgs.wireguard-tools}/bin/wg show interfaces | head -n1)
                  if [ -n "$WG_IFACE" ]; then
                    # Allow DNS to Mullvad's DNS server (required for DNS resolution)
                    ${pkgs.iptables}/bin/iptables -I OUTPUT 1 -d 10.64.0.1 -j ACCEPT

                    # Allow Tailscale control server
                    ${pkgs.iptables}/bin/iptables -I OUTPUT 1 -p tcp --dport 443 -d 5.161.177.144 -j ACCEPT

                    # Add MSS clamping to prevent MTU issues
                    # Clamp MSS to 1380 (1420 WG MTU - 40 bytes for IP/TCP headers)
                    ${pkgs.iptables}/bin/iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
                    ${pkgs.iptables}/bin/iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

                    echo "Added iptables exceptions for DNS and Tailscale control server"
                  fi
                '';
              */

              preStop = ''
                # Find and stop any active WireGuard interfaces
                for iface in $(${pkgs.wireguard-tools}/bin/wg show interfaces); do
                  echo "Stopping WireGuard interface: $iface"
                  ${pkgs.wireguard-tools}/bin/wg-quick down "$iface" 2>/dev/null || true
                done
              '';
            };

            # Systemd service to configure Tailscale exit node
            systemd.services.tailscale-exit-setup = {
              description = "Configure Tailscale exit node for ${city}";
              after = [
                "network.target"
                "mullvad-wireguard.service"
                "tailscaled.service"
              ];
              requires = [ "mullvad-wireguard.service" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                Restart = "on-failure";
                RestartSec = "10s";
              };

              script = ''
                # Wait for Tailscale daemon
                for i in {1..30}; do
                  if ${pkgs.tailscale}/bin/tailscale status &> /dev/null 2>&1 || \
                     ${pkgs.tailscale}/bin/tailscale status 2>&1 | grep -q "Logged out"; then
                    break
                  fi
                  sleep 1
                done

                # Configure Tailscale as exit node
                if ! ${pkgs.tailscale}/bin/tailscale status &> /dev/null; then
                  echo "Tailscale not authenticated. Run: tailscale up --accept-routes=false --accept-dns=false --advertise-exit-node --login-server=https://pond.whenducksfly.com --timeout=30s"
                else
                  ${pkgs.tailscale}/bin/tailscale up --accept-routes=false --accept-dns=false --advertise-exit-node --login-server=https://pond.whenducksfly.com --timeout=30s || true
                  echo "Tailscale exit node configured for ${city} via Mullvad"
                fi
              '';
            };
          };
      };
    };

  exitNodes = [
    {
      name = "ashburn";
      city = "qas";
      country = "us";
      ipSuffix = 10;
    }
    /*
      {
        name = "atlanta";
        city = "atl";
        country = "us";
        ipSuffix = 11;
      }
    */
  ];

in
{
  # Create containers for each exit node
  containers = builtins.listToAttrs (map mkMullvadExitNode exitNodes);

  # Enable NAT for container network
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "ens3";
  };

  # Enable IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
