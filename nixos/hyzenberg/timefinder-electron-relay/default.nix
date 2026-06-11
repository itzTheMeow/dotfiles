{
  config,
  lib,
  xelib,
  ...
}:
lib.mkMerge (
  map (
    host:
    let
      app = config.apps."timefinder-electron-relay-${host}";
    in
    {
      apps."timefinder-electron-relay-${host}" = {
        domain = "tfrl-${host}.xela.codes";
        port = 29387;
        enableDNS = true;
      };

      # forward requests to local machine
      services.nginx.virtualHosts.${app.domain} = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${xelib.hosts.${host}.ip}:${app.portString}";

          # intercept errors and force them to 200s
          extraConfig = ''
            proxy_intercept_errors on;
            error_page 502 503 504 =200 /fallback_200;
          '';
        };

        # fallback 200 page for errors
        locations."/fallback_200" = {
          extraConfig = ''
            internal;
            default_type application/json;
            return 200 '{"status": "success", "message": "Upstream failure"}';
          '';
        };
      };
    }
  ) [ "flynn" ]
)
