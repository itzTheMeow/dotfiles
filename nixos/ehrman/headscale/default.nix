{
  config,
  hostname,
  lib,
  pkgs,
  self,
  xelib,
  ...
}:
let
  app = config.apps.headscale;
in
{
  imports = [ ./headplane.nix ];

  apps.headscale = {
    domain = "pond.whenducksfly.com";
    port = 18888;
    enableProxy = true;
  };

  # add the CLI
  environment.systemPackages = [ pkgs.headscale ];

  services.headscale = {
    enable = true;
    package = pkgs.headscale;
    inherit (app) port;

    # most of these are just the defaults
    settings = {
      server_url = "https://${app.domain}:443";
      policy.mode = "database";

      dns = {
        magic_dns = true;
        base_domain = xelib.apps.homepage.domain; # base domain is the home page
        # give clients their own DNS
        override_local_dns = true;
        nameservers.global = xelib.dns.publicNS.all;
        # records from satellite dotfiles repos (nvstly):
        # explicit extras + one A record per app with a domain, pointing at its host
        extra_records =
          (map (record: { type = "A"; } // record) xelib.externalRecords)
          ++ lib.flatten (
            lib.mapAttrsToList (
              hn: apps:
              lib.mapAttrsToList (_: app: {
                name = app.domain;
                type = "A";
                value = xelib.hosts.${hn}.ip;
              }) (lib.filterAttrs (_: app: app ? domain && app.domain != null) apps)
            ) xelib.externalApps
          )
          ++ (
            # dynamic records from aggregated nginx proxy configs
            let
              allProxies = lib.foldAttrs lib.recursiveUpdate { } (
                map (host: self.nixosConfigurations.${host}.config.nginx.proxy) (
                  builtins.attrNames self.nixosConfigurations
                )
              );
            in
            lib.mapAttrsToList (domain: opts: {
              name = domain;
              type = "A";
              value = opts.target.host;
            }) (lib.filterAttrs (_: opts: opts.local) allProxies)
          );
      };

      # our own embedded DERP relay
      derp.server = {
        enabled = true;
        stun_listen_addr = "0.0.0.0:3478";
        verify_clients = true;
        ipv4 = xelib.dns.addr.${hostname};
        ipv6 = xelib.dns.addr6.${hostname};
      };
    };
  };

  nginx.proxy.${app.domain}.target.host = lib.mkForce "127.0.0.1";

  # STUN port for the DERP server
  networking.firewall.allowedUDPPorts = [ 3478 ];

  # 404 page for base domain
  services.nginx.virtualHosts."whenducksfly.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      return = "404 'NOT FOUND'";
      extraConfig = ''
        default_type text/plain;
      '';
    };
  };
}
