{
  config,
  inputs,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  app = config.apps.degoog;
  mullvad = xelib.apps.mullvad-exit-nodes;

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
        meta.mainProgram = "degoog";
      }
      ''
        mkdir -p $out/bin
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

  # custom declarative settings to be merged into the non-declarative settings file on startup
  settings = {
    proxyEnabled = true;
    proxyUrls = lib.concatStringsSep "\n" (
      map (node: "socks5://${mullvad.ip}:${toString (mullvad.details.basePorts.socks5 + node.index)}") (
        xelib.exitNodes
      )
    );
    searxCompatEnabled = true;
  };
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
      DEGOOG_WIZARD = false;
      DEGOOG_PYTHON_BIN = "${searxPython}/bin/python3";
      DEGOOG_VALKEY_URL = "redis://127.0.0.1:${toString app.details.valkeyPort}";
      LOG_LEVEL = "info";
    };
  };
  systemd.services.degoog.after = [
    "degoog-settings.service"
    "tailscale-online.service"
  ];
  systemd.services.degoog-settings = {
    description = "Merge declarative settings into degoog's server-settings.json";
    wantedBy = [ "degoog.service" ];
    before = [ "degoog.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.escapeShellArgs [
        (lib.getExe (
          pkgs.writeShellApplication {
            name = "degoog-merge-settings";
            runtimeInputs = with pkgs; [
              coreutils
              jq
            ];
            text = ''
              set -euo pipefail

              file="$1"
              ours="$2"

              mkdir -p "$(dirname "$file")"
              tmp="$(mktemp "$(dirname "$file")/.server-settings.json.XXXXXX")"
              trap 'rm -f "$tmp"' EXIT

              if [[ -f "$file" ]]; then
                jq --slurpfile ours "$ours" '.settings = ((.settings // {}) + $ours[0])' "$file" >"$tmp"
              else
                jq -n --slurpfile ours "$ours" '{ settings: $ours[0] }' >"$tmp"
              fi

              chmod 0644 "$tmp"
              mv -f "$tmp" "$file"
            '';
          }
        ))
        "${config.systemd.services.degoog.serviceConfig.WorkingDirectory}/server-settings.json"
        "${pkgs.writeText "degoog-declarative-settings.json" (builtins.toJSON settings)}"
      ];
    };
  };

  # degoog has no option to bind an address (bun binds 0.0.0.0), so proxy via loopback
  #TODO:pr - submitting upstream PR for this
  nginx.proxy.${app.domain}.target.host = lib.mkForce "127.0.0.1";

  sops.envFiles.degoog.DEGOOG_SETTINGS_PASSWORDS = "op://Private/iv2fs5qjw3veizdodpzs5ra63e/password";
}
