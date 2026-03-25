{
  config,
  hostname,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  cfg = config.nginx;
  inherit (lib) mkOption types;

  # default directory for acme certs
  defaultCertDir = "/var/lib/acme/default-cert";
in
{
  options.nginx = {
    enable = lib.mkEnableOption "nginx with default configuration";

    proxy = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              target = mkOption {
                type = types.submodule {
                  options = {
                    host = mkOption {
                      type = types.str;
                      default = xelib.hosts.${hostname}.ip;
                      description = "Domain or IP address for the target (defaults to current host IP)";
                    };
                    protocol = mkOption {
                      type = types.str;
                      default = "http";
                      description = "Protocol for the target URL";
                    };
                    port = mkOption {
                      type = types.nullOr types.int;
                      default = null;
                      description = "Port number for the target (null to omit)";
                    };
                  };
                };
                description = "Configuration for the proxy target";
              };
              local = mkOption {
                type = types.bool;
                description = "If this domain is behind tailscale. Defaulted true for .internal/.xela domains";
              };
              allowedHosts = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "List of hostnames allowed to access the proxy";
              };
              allowedServiceHosts = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "List of service names to allow their host access to the proxy. Merged with allowedHosts";
              };
              proxyWebsockets = mkOption {
                type = types.bool;
                default = true;
                description = "Whether to proxy websocket connections";
              };
              extraConfig = mkOption {
                type = types.functionTo types.attrs;
                default = _: { };
                description = "Extra nginx configuration as a function taking locationExtraConfig";
              };
            };
            config = {
              local = lib.mkDefault (builtins.match ".+\\.(xela|internal)$" name != null);
            };
          }
        )
      );
      default = { };
      description = "Nginx proxy configuration for domains";
    };
  };

  config = lib.mkIf cfg.enable {
    # base nginx config
    services.nginx = {
      enable = true;
      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      clientMaxBodySize = "1g";
    };

    # generate a dummy 100-year cert for catchall requests
    systemd.services.nginx-default-cert = {
      description = "Generate self-signed certificate for nginx default server";
      wantedBy = [ "multi-user.target" ];
      before = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        CERT_DIR="${defaultCertDir}"
        mkdir -p "$CERT_DIR"
        if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
          echo "Generating self-signed certificate for nginx default server..."
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "$CERT_DIR/key.pem" \
            -out "$CERT_DIR/fullchain.pem" \
            -days 36500 \
            -subj "/CN=_"
          chmod 640 "$CERT_DIR"/*.pem
          chown -R nginx:nginx "$CERT_DIR"
          echo "Certificate generated at $CERT_DIR"
        fi
      '';
    };

    # open http(s) ports
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    # add nginx user to acme group so it can read challenge files
    users.users.nginx.extraGroups = [ "acme" ];

    services.nginx.virtualHosts = {
      # default catch-all host for random requests
      "_" = {
        default = true;
        locations."/" = {
          return = "404 'NOT FOUND'";
          extraConfig = ''
            default_type text/plain;
          '';
        };
        # add self-signed cert for SSL catch-all
        addSSL = true;
        sslCertificate = "${defaultCertDir}/fullchain.pem";
        sslCertificateKey = "${defaultCertDir}/key.pem";
      };
    }
    # create each domain host
    // builtins.mapAttrs (
      domain: opts:
      let
        allowedHosts = lib.lists.unique (
          opts.allowedHosts
          # map the list of services to the hosts they run on
          ++ (map (name: xelib.services.${name}.host) opts.allowedServiceHosts)
          ++ xelib.trustedHosts
        );
        locationExtraConfig = lib.optionalAttrs opts.local {
          extraConfig = ''
            # local domains dont have a body size limit
            client_max_body_size 0;

            # allow trusted tailscale hosts
            ${lib.concatMapStringsSep "\n" (h: "allow ${xelib.hosts.${h}.ip}; # ${h}") allowedHosts}

            # allow local ips
            allow 127.0.0.1;
            allow ::1;

            # block all other traffic
            deny all;
          '';
        };
      in
      lib.mkMerge [
        {
          forceSSL = true;
          useACMEHost = domain;
          locations."/" = {
            # build target url
            proxyPass =
              "${opts.target.protocol}://${opts.target.host}"
              + (lib.optionalString (opts.target.port != null) ":${toString opts.target.port}");
            inherit (opts) proxyWebsockets;
          }
          // locationExtraConfig;
        }
        (opts.extraConfig locationExtraConfig)
      ]
    ) cfg.proxy;

    # create local cert for each local domain
    security.acme.certs = builtins.mapAttrs (
      domain: opts:
      let
        stepca = xelib.services.step-ca;
      in
      lib.mkIf opts.local {
        server = "https://${xelib.hosts.${stepca.host}.ip}:${toString stepca.port}/acme/acme/directory";
      }
    ) cfg.proxy;
  };
}
