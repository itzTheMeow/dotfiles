{ pkgs, lib, ... }:
let
  # Function to create a Mullvad exit node container
  mkMullvadExitNode =
    {
      name,
      city,
      country ? "us",
    }:
    {
      name = "mullvad-${name}";
      value = {
        autoStart = true;
        privateNetwork = true;
        hostBridge = "br0";

        config =
          { pkgs, ... }:
          {
            system.stateVersion = "25.11";

            networking.firewall.enable = false;
            networking.useHostResolvConf = lib.mkForce false;

            services.resolved.enable = true;

            # Install necessary packages
            environment.systemPackages = with pkgs; [
              mullvad
              tailscale
            ];

            # Enable Mullvad VPN
            services.mullvad-vpn.enable = true;
            services.mullvad-vpn.package = pkgs.mullvad;

            # Enable Tailscale
            services.tailscale.enable = true;
            services.tailscale.useRoutingFeatures = "server";

            # Systemd service to configure Mullvad and Tailscale
            systemd.services.mullvad-tailscale-setup = {
              description = "Configure Mullvad VPN and Tailscale exit node for ${city}";
              after = [
                "network.target"
                "mullvad-daemon.service"
                "tailscaled.service"
                "tailscale-online.service"
              ];
              wants = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                Restart = "on-failure";
                RestartSec = "10s";
              };

              script = ''
                # Wait for Mullvad daemon to be ready
                for i in {1..30}; do
                  if ${pkgs.mullvad}/bin/mullvad status &> /dev/null; then
                    break
                  fi
                  sleep 1
                done

                # Connect to Mullvad
                ${pkgs.mullvad}/bin/mullvad relay set location ${country} ${city}
                ${pkgs.mullvad}/bin/mullvad lan set allow
                ${pkgs.mullvad}/bin/mullvad auto-connect set on
                ${pkgs.mullvad}/bin/mullvad connect

                # Wait for connection
                for i in {1..60}; do
                  if ${pkgs.mullvad}/bin/mullvad status | grep -q "Connected"; then
                    break
                  fi
                  sleep 1
                done

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
                  echo "Tailscale not authenticated. Please run tailscale up"
                else
                  ${pkgs.tailscale}/bin/tailscale up --advertise-exit-node
                fi
              '';
            };
          };
      };
    };

  exitNodes = [
    {
      name = "ashburn";
      city = "ashburn";
      country = "us";
    }
    {
      name = "atlanta";
      city = "atlanta";
      country = "us";
    }
  ];

in
{
  # Create containers for each exit node
  containers = builtins.listToAttrs (map mkMullvadExitNode exitNodes);

  # Configure bridge network for containers
  networking.bridges.br0.interfaces = [ ];
  networking.interfaces.br0 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = "10.250.0.1";
        prefixLength = 24;
      }
    ];
  };

  # Ensure bridge is created early
  systemd.services."container@".after = [
    "network.target"
    "sys-subsystem-net-devices-br0.device"
  ];
  systemd.services."container@".wants = [ "sys-subsystem-net-devices-br0.device" ];

  # Enable NAT for container network
  networking.nat = {
    enable = true;
    internalInterfaces = [ "br0" ];
    externalInterface = "ens3";
  };

  # Enable IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
