{
  config,
  hostname,
  lib,
  xelib,
  ...
}:
let
  cfg = config.apps;
in
{
  options.apps = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, name, ... }:
        {
          options = {
            port = lib.mkOption {
              type = lib.types.int;
              description = "Port number for the app";
            };
            domain = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Domain this app runs on";
            };
            details = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = "Any extra details that might be needed. Used for extra ports and such";
            };

            # options for homepage
            name = lib.mkOption {
              type = lib.types.str;
              default = xelib.toTitleCase name;
              description = "Friendly name for the app displayed on the homepage. Defaults to title case of attr name";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "A short description of the service for the homepage";
            };
            icon = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Name of the homepage icon to use. Defaults to app attr name";
            };

            enableProxy = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Automatically configure nginx proxy for the app";
            };
            enableDNS = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Automatically configure the dns zone for the domain. Requires domain to be formatted correctly and under our control. Subdomains only";
            };
            # these are auto-derived for utility
            host = lib.mkOption {
              type = lib.types.str;
              default = hostname;
              description = "Name of the host this app is on (defaults to hostname)";
            };
            ip = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "IP address of the app host (auto-derived)";
            };
            url = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "Full URL to the host without trailing slash (auto-derived)";
            };
            portString = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "String representation of the port (auto-derived)";
            };
          };
          config = {
            ip = lib.mkDefault xelib.hosts.${config.host}.ip;
            portString = lib.mkDefault (toString config.port);
            url = lib.mkDefault (
              if config.domain != null then
                "https://${config.domain}"
              else
                "http://${config.ip}:${config.portString}"
            );
          };
        }
      )
    );
    default = { };
    description = "List of apps to define";
  };

  config = lib.mkIf (cfg != { }) {
    # set up proxies for apps
    nginx.proxy = lib.mkMerge (
      lib.mapAttrsToList (
        _: opts:
        lib.mkIf opts.enableProxy {
          "${opts.domain}".target = {
            host = opts.ip;
            port = opts.port;
          };
        }
      ) cfg
    );
    # set up dns
    dnszones.list = lib.mkMerge (
      lib.mapAttrsToList (
        _: opts:
        let
          # just split out the domain/subdomain
          split = xelib.dns.splitDomain opts.domain;
        in
        lib.mkIf opts.enableDNS {
          "${split.domain}".subdomains."${split.subdomain}" = xelib.dns.pointHost opts.host;
        }
      ) cfg
    );
  };
}
