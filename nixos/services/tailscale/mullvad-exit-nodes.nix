{ lib, ... }:
let
  configDir = "/var/lib/mullvad-configs";
  mkMullvadExitNode =
    {
      name,
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

            # forward DNS queries to Mullvad's DNS
            networking.nameservers = [ "10.64.0.1" ];

            environment.systemPackages = with pkgs; [
              # actually needed
              openresolv
              tailscale
              wireguard-tools
              # debug
              dig
              iptables
              iputils
              net-tools
              tcpdump

              # init script
              (pkgs.writeShellScriptBin "tailscale-init" ''
                if [ -z "$1" ]; then
                  echo "Usage: tailscale-init <authkey>"
                  exit 1
                fi

                echo "Initializing Tailscale exit node..."
                ${pkgs.tailscale}/bin/tailscale up \
                  --accept-dns=false \
                  --accept-routes=false \
                  --advertise-exit-node \
                  --hostname="mullvad-${name}" \
                  --login-server=https://pond.whenducksfly.com \
                  --authkey="$1"

                echo "Tailscale exit node configured successfully!"
              '')
            ];

            services.tailscale.enable = true;
            services.tailscale.useRoutingFeatures = "both";

            # set up Mullvad WireGuard connection
            # put Mullvad configs in /var/lib/mullvad-configs/*.conf (configDir)
            systemd.services.mullvad-wireguard = {
              description = "Mullvad WireGuard VPN";
              after = [ "network-pre.target" ];
              before = [ "network.target" ];
              wants = [ "network-pre.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };

              script = ''
                CONFIG_DIR="${configDir}"

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

              preStop = ''
                # Find and stop any active WireGuard interfaces
                for iface in $(${pkgs.wireguard-tools}/bin/wg show interfaces); do
                  echo "Stopping WireGuard interface: $iface"
                  ${pkgs.wireguard-tools}/bin/wg-quick down "$iface" 2>/dev/null || true
                done
              '';
            };

            # Setup NAT for Tailscale exit node traffic through Mullvad
            systemd.services.mullvad-exit-nat = {
              description = "NAT rules for Tailscale => Mullvad";
              after = [ "mullvad-wireguard.service" ];
              requires = [ "mullvad-wireguard.service" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };

              script = ''
                # Get the WireGuard interface name
                WG_IFACE=$(${pkgs.wireguard-tools}/bin/wg show interfaces | head -n1)

                if [ -z "$WG_IFACE" ]; then
                  echo "No WireGuard interface found"
                  exit 1
                fi

                echo "Setting up NAT for Tailscale => $WG_IFACE"

                # IPv4 NAT and forwarding rules
                ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o "$WG_IFACE" -j MASQUERADE
                ${pkgs.iptables}/bin/iptables -A FORWARD -i tailscale0 -o "$WG_IFACE" -j ACCEPT
                ${pkgs.iptables}/bin/iptables -A FORWARD -i "$WG_IFACE" -o tailscale0 -m state --state RELATED,ESTABLISHED -j ACCEPT

                # IPv6 NAT and forwarding rules
                ${pkgs.iptables}/bin/ip6tables -t nat -A POSTROUTING -o "$WG_IFACE" -j MASQUERADE
                ${pkgs.iptables}/bin/ip6tables -A FORWARD -i tailscale0 -o "$WG_IFACE" -j ACCEPT
                ${pkgs.iptables}/bin/ip6tables -A FORWARD -i "$WG_IFACE" -o tailscale0 -m state --state RELATED,ESTABLISHED -j ACCEPT

                echo "NAT rules (IPv4 and IPv6) configured successfully"
              '';

              preStop = ''
                # Get the WireGuard interface name
                WG_IFACE=$(${pkgs.wireguard-tools}/bin/wg show interfaces | head -n1)

                if [ -n "$WG_IFACE" ]; then
                  echo "Removing NAT rules for $WG_IFACE"
                  
                  # IPv4 cleanup
                  ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o "$WG_IFACE" -j MASQUERADE 2>/dev/null || true
                  ${pkgs.iptables}/bin/iptables -D FORWARD -i tailscale0 -o "$WG_IFACE" -j ACCEPT 2>/dev/null || true
                  ${pkgs.iptables}/bin/iptables -D FORWARD -i "$WG_IFACE" -o tailscale0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
                  
                  # IPv6 cleanup
                  ${pkgs.iptables}/bin/ip6tables -t nat -D POSTROUTING -o "$WG_IFACE" -j MASQUERADE 2>/dev/null || true
                  ${pkgs.iptables}/bin/ip6tables -D FORWARD -i tailscale0 -o "$WG_IFACE" -j ACCEPT 2>/dev/null || true
                  ${pkgs.iptables}/bin/ip6tables -D FORWARD -i "$WG_IFACE" -o tailscale0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
                fi
              '';
            };

            # Health check and auto-recovery for Mullvad WireGuard
            systemd.services.mullvad-health-check = {
              description = "Mullvad WireGuard Health Check";
              after = [ "mullvad-wireguard.service" ];
              requires = [ "mullvad-wireguard.service" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                Restart = "always";
                RestartSec = "30s";
              };

              script = ''
                echo "Starting Mullvad health check service..."

                while true; do
                  # Wait between checks
                  sleep 60
                  
                  # Check if WireGuard interface is up
                  WG_IFACE=$(${pkgs.wireguard-tools}/bin/wg show interfaces | head -n1)
                  
                  if [ -z "$WG_IFACE" ]; then
                    echo "ERROR: No WireGuard interface found. Restarting mullvad-wireguard service..."
                    systemctl restart mullvad-wireguard.service
                    sleep 1
                    systemctl restart mullvad-exit-nat.service
                    continue
                  fi
                  
                  # Check if interface has received data recently (handshake is active)
                  HANDSHAKE=$(${pkgs.wireguard-tools}/bin/wg show "$WG_IFACE" latest-handshakes | ${pkgs.gawk}/bin/awk '{print $2}')
                  CURRENT_TIME=$(date +%s)
                  
                  if [ -n "$HANDSHAKE" ]; then
                    TIME_SINCE_HANDSHAKE=$((CURRENT_TIME - HANDSHAKE))
                    
                    # If no handshake in the last 3 minutes, connection is likely dead
                    if [ "$TIME_SINCE_HANDSHAKE" -gt 180 ]; then
                      echo "WARNING: No handshake in $TIME_SINCE_HANDSHAKE seconds. Connection may be dead."
                    fi
                  fi
                  
                  # Perform connectivity test - try to ping Mullvad's DNS
                  if ! ${pkgs.iputils}/bin/ping -c 1 -W 5 -I "$WG_IFACE" 10.64.0.1 &>/dev/null; then
                    echo "ERROR: Ping to Mullvad DNS (10.64.0.1) failed. Connection is down, restarting..."
                    
                    # Restart mullvad-wireguard which will pick a new random config
                    systemctl restart mullvad-wireguard.service
                    sleep 1
                    systemctl restart mullvad-exit-nat.service
                    
                    echo "Switched to new Mullvad server config"
                  else
                    echo "Health check passed - connection is healthy"
                  fi
                done
              '';
            };
          };
      };
    };

  # exit node definitions
  exitNodes = [
    {
      name = "ashburn";
      ipSuffix = 10;
    }
    {
      name = "atlanta";
      ipSuffix = 11;
    }
  ];
in
{
  # create the actual containers for each exit node
  containers = builtins.listToAttrs (map mkMullvadExitNode exitNodes);

  # enable NAT for container network
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "ens3";
  };

  # enable IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
