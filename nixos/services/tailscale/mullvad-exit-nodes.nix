{ pkgs, lib, ... }:
let
  # Function to create a Mullvad VPN gateway container (Layer 1)
  mkMullvadGateway =
    {
      name,
      city,
      ipSuffix,
    }:
    {
      name = "mullvad-gw-${name}";
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
            networking.nameservers = [ "10.64.0.1" ];

            # Enable IP forwarding for nested container
            boot.kernel.sysctl = {
              "net.ipv4.ip_forward" = 1;
              "net.ipv6.conf.all.forwarding" = 1;
            };

            # Install necessary packages
            environment.systemPackages = with pkgs; [
              wireguard-tools
              iptables
            ];

            # WireGuard will be configured dynamically from configs
            # Place Mullvad configs in /var/lib/mullvad-configs/*.conf

            # Systemd service to setup Mullvad WireGuard and NAT
            systemd.services.mullvad-wireguard = {
              description = "Mullvad WireGuard VPN Gateway for ${city}";
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

                # Get WireGuard interface name
                WG_IFACE=$(${pkgs.wireguard-tools}/bin/wg show interfaces | head -n1)
                if [ -n "$WG_IFACE" ]; then
                  # Set up NAT for nested container (10.251.0.0/24)
                  ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o "$WG_IFACE" -j MASQUERADE
                  ${pkgs.iptables}/bin/iptables -A FORWARD -i ve-+ -o "$WG_IFACE" -j ACCEPT
                  ${pkgs.iptables}/bin/iptables -A FORWARD -i "$WG_IFACE" -o ve-+ -m state --state RELATED,ESTABLISHED -j ACCEPT
                  
                  # Add MSS clamping
                  ${pkgs.iptables}/bin/iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
                  
                  echo "Mullvad VPN gateway configured, ready for nested Tailscale container"
                fi
              '';

              preStop = ''
                # Find and stop any active WireGuard interfaces
                for iface in $(${pkgs.wireguard-tools}/bin/wg show interfaces); do
                  echo "Stopping WireGuard interface: $iface"
                  ${pkgs.wireguard-tools}/bin/wg-quick down "$iface" 2>/dev/null || true
                done
              '';
            };

            # Nested Tailscale container (Layer 2)
            containers.tailscale = {
              autoStart = true;
              privateNetwork = true;
              hostAddress = "10.251.0.1";
              localAddress = "10.251.0.2";

              config =
                { pkgs, ... }:
                {
                  system.stateVersion = "25.11";

                  networking.firewall.enable = false;
                  networking.useHostResolvConf = lib.mkForce false;
                  # Use the gateway's DNS (which uses Mullvad)
                  networking.nameservers = [ "10.251.0.1" ];
                  # Default route through the gateway
                  networking.defaultGateway = {
                    address = "10.251.0.1";
                    interface = "eth0";
                  };

                  environment.systemPackages = with pkgs; [ tailscale ];

                  services.tailscale.enable = true;
                  services.tailscale.useRoutingFeatures = "server";

                  # Systemd service to configure Tailscale exit node
                  systemd.services.tailscale-exit-setup = {
                    description = "Configure Tailscale exit node for ${city}";
                    after = [
                      "network.target"
                      "tailscaled.service"
                    ];
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      Restart = "on-failure";
                      RestartSec = "10s";
                    };

                    script = ''
                      # Wait for Tailscale daemon and internet connectivity
                      for i in {1..30}; do
                        if ${pkgs.tailscale}/bin/tailscale status &> /dev/null 2>&1 || \
                           ${pkgs.tailscale}/bin/tailscale status 2>&1 | grep -q "Logged out"; then
                          break
                        fi
                        sleep 1
                      done

                      # Configure Tailscale as exit node
                      if ! ${pkgs.tailscale}/bin/tailscale status &> /dev/null; then
                        echo "Tailscale not authenticated. Run: nixos-container root-login mullvad-gw-${name}, then: nixos-container root-login tailscale, then: tailscale up --accept-routes=false --advertise-exit-node --login-server=https://pond.whenducksfly.com --timeout=30s"
                      else
                        ${pkgs.tailscale}/bin/tailscale up --accept-routes=false --advertise-exit-node --login-server=https://pond.whenducksfly.com --timeout=30s || true
                        echo "Tailscale exit node configured for ${city} via Mullvad"
                      fi
                    '';
                  };
                };
            };

            # Enable NAT for nested container
            networking.nat = {
              enable = true;
              internalInterfaces = [ "ve-+" ];
              externalInterface = "wg0"; # Will be the WireGuard interface
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
    {
      name = "atlanta";
      city = "atl";
      country = "us";
      ipSuffix = 11;
    }
  ];

in
{
  # Create gateway containers for each exit node
  containers = builtins.listToAttrs (map mkMullvadGateway exitNodes);

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
