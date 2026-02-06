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

            # Install necessary packages
            environment.systemPackages = with pkgs; [
              mullvad
              tailscale
            ];

            # Enable Mullvad VPN
            services.mullvad-vpn.enable = true;
            services.mullvad-vpn.package = pkgs.mullvad;

            # Enable Tailscale but don't start it automatically
            # We'll start it manually after Mullvad is connected
            services.tailscale.enable = true;
            services.tailscale.useRoutingFeatures = "server";

            # Prevent Tailscale from starting automatically
            systemd.services.tailscaled.wantedBy = lib.mkForce [ ];

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

                # Check if Mullvad is logged in
                if ! ${pkgs.mullvad}/bin/mullvad account get &> /dev/null; then
                  echo "Mullvad not logged in. Please run: mullvad account login <account-number>"
                  exit 0
                fi

                # Configure Mullvad
                ${pkgs.mullvad}/bin/mullvad relay set location ${country} ${city}
                ${pkgs.mullvad}/bin/mullvad lan set allow
                ${pkgs.mullvad}/bin/mullvad auto-connect set on

                # Try to connect to Mullvad
                if ${pkgs.mullvad}/bin/mullvad connect; then
                  # Wait for connection
                  for i in {1..30}; do
                    if ${pkgs.mullvad}/bin/mullvad status | grep -q "Connected"; then
                      echo "Mullvad connected to ${city}"
                      break
                    fi
                    sleep 1
                  done
                  
                  # Wait a bit for Mullvad to set up routing
                  sleep 2
                  
                  echo "Routing configured through Mullvad"
                else
                  echo "Failed to connect to Mullvad"
                  exit 0
                fi

                # Now start Tailscale
                systemctl start tailscaled.service

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
                  echo "Tailscale not authenticated. Please run: tailscale up --accept-dns=false --advertise-exit-node --login-server=https://pond.whenducksfly.com"
                else
                  ${pkgs.tailscale}/bin/tailscale up --accept-dns=false --advertise-exit-node --login-server=https://pond.whenducksfly.com
                  echo "Tailscale exit node configured"
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
    {
      name = "atlanta";
      city = "atl";
      country = "us";
      ipSuffix = 11;
    }
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
