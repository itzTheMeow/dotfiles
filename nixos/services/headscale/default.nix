{
  lib,
  pkgs,
  xelib,
  ...
}@inputs:
let
  svc = xelib.services.headscale;
in
lib.mkMerge [
  {
    # add the CLI
    environment.systemPackages = [ pkgs.headscale ];

    services.headscale = {
      enable = true;
      package = pkgs.headscale;
      port = svc.port;

      # most of these are just the defaults
      settings = {
        server_url = "https://${svc.domain}:443";
        policy.mode = "database";

        dns = {
          magic_dns = true;
          base_domain = xelib.services.homepage.domain; # base domain is the home page
          override_local_dns = false;
          extra_records = [
            {
              name = "nvstly.internal";
              type = "A";
              value = "100.64.0.5";
            }
            {
              name = "nginx.nvstly.internal";
              type = "A";
              value = "100.64.0.5";
            }
            {
              name = "portainer.nvstly.internal";
              type = "A";
              value = "100.64.0.5";
            }
            {
              name = "portainer.xela.internal";
              type = "A";
              value = "100.64.0.2";
            }
            {
              name = "kuma.nvstly.internal";
              type = "A";
              value = "100.64.0.5";
            }
            {
              name = "postiz.nvstly.internal";
              type = "A";
              value = "100.64.0.5";
            }
            {
              name = "redis.nvstly.internal";
              type = "A";
              value = "100.64.0.5";
            }
            {
              name = "beszel.nvstly.internal";
              type = "A";
              value = "100.64.0.5";
            }
          ]
          ++ (
            # dynamic records from service list
            builtins.map
              (
                name:
                let
                  s = xelib.services.${name};
                in
                {
                  name = s.domain;
                  type = "A";
                  value = xelib.hosts.${s.host}.ip;
                }
              )
              (
                builtins.filter (name: xelib.isLocalDomain (xelib.services.${name}.domain or "")) (
                  builtins.attrNames xelib.services
                )
              )
          );
        };
      };
    };
  }
  (import ./headplane.nix inputs)
  (xelib.mkNginxProxy svc.domain "http://127.0.0.1:${toString svc.port}" { })
]
