{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  app = config.apps.degoog;

  # the flake only ships git as a runtime input, but the curl transports shell out to
  # curl/curl-impersonate and the searxng compat layer shells out to python
  #TODO: look into this as a possible upstream fix
  searxPython = pkgs.python3.withPackages (ps: [
    ps.babel
    ps.python-dateutil
    ps.lxml
  ]);
  package =
    pkgs.runCommand "degoog"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        passthru.meta.mainProgram = "degoog";
      }
      ''
        cp ${inputs.degoog.packages.${pkgs.system}.default}/bin/degoog $out/bin/degoog
        chmod u+w $out/bin/degoog
        wrapProgram $out/bin/degoog --prefix PATH : ${
          lib.makeBinPath [
            pkgs.curl
            pkgs.curl-impersonate
            searxPython
          ]
        }
      '';
in
{
  apps.degoog = {
    domain = "degoog.xela";
    port = 64335;
    enableProxy = true;
    details.valkeyPort = 64336;

    description = "Private Search";
  };

  # set up redis for valkey
  services.redis.servers.degoog = {
    enable = true;
    port = app.details.valkeyPort;
    save = [
      [
        300
        1
      ]
      [
        60
        10
      ]
    ];
  };

  services.degoog = {
    enable = true;
    inherit package;
    environmentFile = config.sops.secrets.degoog.path;
    environment = {
      DEGOOG_PORT = app.port;
      DEGOOG_BASE_URL = app.url;
      DEGOOG_PUBLIC_INSTANCE = false;
      # TODO: turn back off once the engines are installed
      DEGOOG_WIZARD = true;
      DEGOOG_PYTHON_BIN = "${searxPython}/bin/python3";
      DEGOOG_VALKEY_URL = "redis://127.0.0.1:${toString app.details.valkeyPort}";
      LOG_LEVEL = "info";
    };
  };
  systemd.services.degoog.after = [ "tailscale-online.service" ];

  # degoog has no option to bind an address (bun binds 0.0.0.0), so proxy via loopback
  #TODO:pr - submitting upstream PR for this
  nginx.proxy.${app.domain}.target.host = lib.mkForce "127.0.0.1";

  sops.envFiles.degoog.DEGOOG_SETTINGS_PASSWORDS = "op://Private/iv2fs5qjw3veizdodpzs5ra63e/password";
}
